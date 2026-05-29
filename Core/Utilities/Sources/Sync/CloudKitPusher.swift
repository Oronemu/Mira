import Foundation
import CoreKit

/// Subscribes to entry/insight change streams, batches them into a
/// durable `PendingPushQueue`, and flushes them to `CloudKitDatabase`
/// on a debounce cadence. Idempotent: a push is keyed on entity UUID,
/// so duplicates collapse into one CloudKit record. Failed flushes
/// leave items in the queue for the next tick — caller decides when
/// to retry by driving `flushLoop` (via `start`) or calling
/// `flushOnce()` on demand.
public actor CloudKitPusher {
    private let database: any CloudKitDatabase
    private let codec: SyncPayloadCodec
    private let queue: PendingPushQueue
    private let entries: any EntryRepository
    private let insights: any InsightRepository
    private let photos: any PhotoStoring
    private let customStickers: any CustomStickerStoring
    private let batchLimit: Int
    private let debounce: Duration
    private let clock: any Clock<Duration>

    private var runningTask: Task<Void, Never>?

    public init(
        database: any CloudKitDatabase,
        codec: SyncPayloadCodec,
        queue: PendingPushQueue,
        entries: any EntryRepository,
        insights: any InsightRepository,
        photos: any PhotoStoring,
        customStickers: any CustomStickerStoring,
        batchLimit: Int = 50,
        debounce: Duration = .seconds(2),
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.database = database
        self.codec = codec
        self.queue = queue
        self.entries = entries
        self.insights = insights
        self.photos = photos
        self.customStickers = customStickers
        self.batchLimit = batchLimit
        self.debounce = debounce
        self.clock = clock
    }

    /// Begins observing change streams and scheduling flushes. Safe to
    /// call multiple times; extra calls are ignored.
    public func start() {
        guard runningTask == nil else { return }
        runningTask = Task { [weak self] in
            await self?.run()
        }
    }

    public func stop() {
        runningTask?.cancel()
        runningTask = nil
    }

    /// Drains a single batch from the queue and pushes it. For each
    /// delete, writes a tombstone record alongside removing the original
    /// so other devices can propagate the delete on pull. Leaves items
    /// in the queue on failure so the next call retries them.
    public func flushOnce() async {
        let batch = await queue.drain(limit: batchLimit)
        guard !batch.isEmpty else { return }
        MiraLog.logger(.general).info("Sync: flushing batch of \(batch.count) item(s): \(batch.map { "\($0.kind.rawValue):\($0.id.uuidString.prefix(8))" }.joined(separator: ", "), privacy: .public)")

        var upsertRecords: [SyncCloudRecord] = []
        var tombstoneRecords: [SyncCloudRecord] = []
        var deleteIDs: [String] = []

        for item in batch {
            switch item.operation {
            case .upsert:
                if let record = await resolveUpsert(item: item) {
                    upsertRecords.append(record)
                }
            case .delete:
                if let tombstone = await resolveTombstone(item: item) {
                    tombstoneRecords.append(tombstone)
                }
                deleteIDs.append(item.id.uuidString)
            }
        }

        do {
            let saves = upsertRecords + tombstoneRecords
            if !saves.isEmpty {
                MiraLog.logger(.general).info("Sync: saving \(saves.count) record(s) to CloudKit: \(saves.map { "\($0.kind.rawValue):\($0.id.prefix(16))" }.joined(separator: ", "), privacy: .public)")
                try await database.save(saves)
                MiraLog.logger(.general).info("Sync: CloudKit save succeeded")
            }
            if !deleteIDs.isEmpty {
                try await database.delete(deleteIDs)
            }
            try await queue.markCompleted(batch.map(\.id))
        } catch {
            MiraLog.logger(.general).error("CloudKit push failed, leaving \(batch.count) items queued: \(error.localizedDescription)")
        }
    }

    public func enqueueEntry(_ change: EntryChange) async {
        switch change {
        case .upserted(let snapshot):
            try? await queue.enqueue(
                .init(id: snapshot.id, kind: .entry, operation: .upsert, updatedAt: snapshot.updatedAt)
            )
            MiraLog.logger(.general).info("Sync: enqueued entry \(snapshot.id.uuidString, privacy: .public) with \(snapshot.photos.count) photo(s)")
            // Photo bytes ride as their own records so the entry's
            // ciphertext stays lean. CloudKit dedups by record name, so
            // re-enqueueing a photo we've already pushed just replaces
            // the existing asset — idempotent, wasteful at worst.
            for photo in snapshot.photos {
                try? await queue.enqueue(
                    .init(id: photo.id, kind: .photo, operation: .upsert, updatedAt: photo.createdAt)
                )
                MiraLog.logger(.general).info("Sync: enqueued photo blob \(photo.id.uuidString, privacy: .public) at \(photo.relativePath, privacy: .public)")
            }
        case .deleted(let id):
            try? await queue.enqueue(
                .init(id: id, kind: .entry, operation: .delete, updatedAt: .now)
            )
        }
    }

    public func enqueueInsight(_ change: InsightChange) async {
        let item: PendingPushQueue.Item
        switch change {
        case .upserted(let snapshot):
            item = .init(id: snapshot.id, kind: .insight, operation: .upsert, updatedAt: snapshot.createdAt)
        case .deleted(let id):
            item = .init(id: id, kind: .insight, operation: .delete, updatedAt: .now)
        }
        try? await queue.enqueue(item)
    }

    /// One-time backfill for installs that predate the photo-blob sync
    /// pipeline. Walks every entry with photos and enqueues .photo push
    /// items so their bytes ride up on the next flush. Idempotent: CK
    /// dedups by record name, and the caller is expected to gate via a
    /// persisted flag so we don't spam the queue on every launch.
    public func backfillPhotoBlobs() async {
        let all = (try? await entries.fetch(matching: .all)) ?? []
        for snapshot in all where !snapshot.photos.isEmpty {
            for photo in snapshot.photos {
                try? await queue.enqueue(
                    .init(id: photo.id, kind: .photo, operation: .upsert, updatedAt: photo.createdAt)
                )
            }
        }
    }

    // MARK: - Private

    private func run() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in await observeEntries() }
            group.addTask { [self] in await observeInsights() }
            group.addTask { [self] in await observeCustomStickers() }
            group.addTask { [self] in await flushLoop() }
        }
    }

    private nonisolated func observeEntries() async {
        for await change in await entries.changes() {
            if Task.isCancelled { return }
            await enqueueEntry(change)
        }
    }

    private nonisolated func observeInsights() async {
        for await change in await insights.changes() {
            if Task.isCancelled { return }
            await enqueueInsight(change)
        }
    }

    private nonisolated func observeCustomStickers() async {
        for await change in customStickers.changes() {
            if Task.isCancelled { return }
            await enqueueCustomSticker(change)
        }
    }

    public func enqueueCustomSticker(_ change: CustomStickerChange) async {
        switch change {
        case .upserted(let asset):
            try? await queue.enqueue(
                .init(id: asset.id, kind: .userSticker, operation: .upsert, updatedAt: asset.createdAt)
            )
            MiraLog.logger(.general).info("Sync: enqueued user sticker \(asset.id.uuidString, privacy: .public)")
        case .deleted(let id):
            try? await queue.enqueue(
                .init(id: id, kind: .userSticker, operation: .delete, updatedAt: .now)
            )
        }
    }

    private func flushLoop() async {
        while !Task.isCancelled {
            do {
                try await clock.sleep(for: debounce)
            } catch {
                return
            }
            await flushOnce()
        }
    }

    private func resolveUpsert(item: PendingPushQueue.Item) async -> SyncCloudRecord? {
        do {
            switch item.kind {
            case .entry:
                guard let snapshot = try await entries.fetch(id: item.id) else { return nil }
                let ciphertext = try await codec.encode(snapshot)
                return SyncCloudRecord(
                    id: item.id.uuidString,
                    kind: .entry,
                    ciphertext: ciphertext,
                    updatedAt: snapshot.updatedAt
                )
            case .insight:
                guard let snapshot = try await insights.fetch(id: item.id) else { return nil }
                let ciphertext = try await codec.encode(snapshot)
                return SyncCloudRecord(
                    id: item.id.uuidString,
                    kind: .insight,
                    ciphertext: ciphertext,
                    updatedAt: snapshot.createdAt
                )
            case .photo:
                return try await resolvePhotoUpsert(item: item)
            case .userSticker:
                return try await resolveCustomStickerUpsert(item: item)
            case .deleted:
                return nil
            }
        } catch {
            MiraLog.logger(.general).error("Failed to encode push for \(item.id.uuidString): \(error.localizedDescription)")
            return nil
        }
    }

    private func resolvePhotoUpsert(item: PendingPushQueue.Item) async throws -> SyncCloudRecord? {
        let relativePath = Self.photoRelativePath(for: item.id)
        MiraLog.logger(.general).info("Sync: resolving photo blob \(item.id.uuidString, privacy: .public) at \(relativePath, privacy: .public)")
        guard await photos.exists(relativePath: relativePath) else {
            MiraLog.logger(.general).error("Sync: photo file missing on disk for \(item.id.uuidString, privacy: .public) — skipping push")
            return nil
        }
        let bytes = try await photos.read(relativePath: relativePath)
        MiraLog.logger(.general).info("Sync: read \(bytes.count) bytes for photo \(item.id.uuidString, privacy: .public)")
        let blob = PhotoBlobSnapshot(id: item.id, createdAt: item.updatedAt)
        let envelope = try await codec.encode(blob)
        let assetCiphertext = try await codec.sealAsset(bytes)
        return SyncCloudRecord(
            id: Self.photoRecordID(for: item.id),
            kind: .photo,
            ciphertext: envelope,
            assetCiphertext: assetCiphertext,
            updatedAt: item.updatedAt
        )
    }

    /// Canonical disk location for a photo id. Must match
    /// `PhotoStorageService.save(_:id:)`.
    private static func photoRelativePath(for id: UUID) -> String {
        "Photos/\(id.uuidString).jpg"
    }

    /// Namespaced CloudKit record name for a photo blob so it can't
    /// collide with entry or insight records in the same zone.
    public static func photoRecordID(for id: UUID) -> String {
        "photo-\(id.uuidString)"
    }

    private func resolveCustomStickerUpsert(item: PendingPushQueue.Item) async throws -> SyncCloudRecord? {
        let relativePath = Self.customStickerRelativePath(for: item.id)
        guard await customStickers.exists(id: item.id) else {
            MiraLog.logger(.general).error("Sync: user sticker missing on disk for \(item.id.uuidString, privacy: .public) — skipping push")
            return nil
        }
        let bytes = try await customStickers.read(relativePath: relativePath)
        let blob = CustomStickerBlobSnapshot(id: item.id, createdAt: item.updatedAt)
        let envelope = try await codec.encode(blob)
        let assetCiphertext = try await codec.sealAsset(bytes)
        return SyncCloudRecord(
            id: Self.customStickerRecordID(for: item.id),
            kind: .userSticker,
            ciphertext: envelope,
            assetCiphertext: assetCiphertext,
            updatedAt: item.updatedAt
        )
    }

    /// One-time backfill for installs that predate the user-sticker sync
    /// pipeline. Same shape as `backfillPhotoBlobs()` — enumerates the
    /// local store and enqueues an upsert for each existing sticker.
    public func backfillCustomStickerBlobs() async {
        let assets = (try? await customStickers.list()) ?? []
        for asset in assets {
            try? await queue.enqueue(
                .init(id: asset.id, kind: .userSticker, operation: .upsert, updatedAt: asset.createdAt)
            )
        }
    }

    /// Canonical disk location for a user sticker id. Must match
    /// `CustomStickerStorageService.save(_:id:createdAt:)`.
    private static func customStickerRelativePath(for id: UUID) -> String {
        "Stickers/\(id.uuidString).png"
    }

    /// Namespaced CloudKit record name for a user-sticker blob.
    public static func customStickerRecordID(for id: UUID) -> String {
        "sticker-\(id.uuidString)"
    }

    private func resolveTombstone(item: PendingPushQueue.Item) async -> SyncCloudRecord? {
        do {
            let tombstone = SyncTombstone(id: item.id, originalKind: item.kind, deletedAt: item.updatedAt)
            let ciphertext = try await codec.encode(tombstone)
            return SyncCloudRecord(
                id: Self.tombstoneRecordID(for: item.id),
                kind: .deleted,
                ciphertext: ciphertext,
                updatedAt: item.updatedAt
            )
        } catch {
            MiraLog.logger(.general).error("Failed to encode tombstone for \(item.id.uuidString): \(error.localizedDescription)")
            return nil
        }
    }

    /// Tombstones live in a separate record-name namespace so they can
    /// coexist with the original record's recordID until the delete call
    /// finishes (CKModifyRecordsOperation runs saves before deletes in
    /// the same batch, but the tombstone needs its own ID anyway because
    /// its record type — "Deleted" — differs from the original's).
    public static func tombstoneRecordID(for id: UUID) -> String {
        "\(id.uuidString)-tombstone"
    }
}
