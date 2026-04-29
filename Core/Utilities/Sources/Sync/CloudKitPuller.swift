import Foundation
import CoreKit

/// Reads incoming CloudKit changes, decrypts each payload, and applies
/// it to the local repositories. Paginates via the server change token
/// persisted in `ChangeTokenStore`; when CloudKit tells us the token is
/// expired (zone reset, retention window elapsed), we clear the token
/// and the next pull does a full resync from scratch.
///
/// Conflict resolution is last-write-wins on `updatedAt` (entries) and
/// `createdAt` (insights — effectively immutable once generated).
/// Tombstones carry a `deletedAt` and lose only when the local row's
/// timestamp is strictly newer (i.e., someone else edited after the
/// delete was issued — the edit resurrects the entity).
public actor CloudKitPuller {
    private let database: any CloudKitDatabase
    private let codec: SyncPayloadCodec
    private let tokens: ChangeTokenStore
    private let entries: any EntryRepository
    private let insights: any InsightRepository
    private let photos: any PhotoStoring

    public init(
        database: any CloudKitDatabase,
        codec: SyncPayloadCodec,
        tokens: ChangeTokenStore,
        entries: any EntryRepository,
        insights: any InsightRepository,
        photos: any PhotoStoring
    ) {
        self.database = database
        self.codec = codec
        self.tokens = tokens
        self.entries = entries
        self.insights = insights
        self.photos = photos
    }

    /// Drains all pending CloudKit changes in one call. Loops until the
    /// server stops reporting `moreComing`. Safe to call concurrently
    /// with pushes — actor isolation serialises internal state.
    public func pullOnce() async {
        var retriesAfterExpiry = 0
        repeat {
            let startToken = await tokens.load()
            do {
                let batch = try await database.fetchChanges(since: startToken)
                await apply(batch)
                if let token = batch.newToken {
                    try? await tokens.save(token)
                }
                if !batch.moreComing { return }
            } catch CloudKitPullError.tokenExpired {
                await tokens.clear()
                MiraLog.logger(.general).warning("CloudKit change token expired, resetting for full resync")
                retriesAfterExpiry += 1
                if retriesAfterExpiry > 1 {
                    // Something is wrong — clearing didn't help. Stop
                    // looping instead of spinning.
                    return
                }
            } catch {
                MiraLog.logger(.general).error("CloudKit pull failed: \(error.localizedDescription)")
                return
            }
        } while true
    }

    private func apply(_ batch: CloudKitPullBatch) async {
        // Process photo blobs before entries so an entry's photos exist
        // on disk by the time the UI renders the entry. Records typically
        // arrive in the same batch when a device pushed an entry with
        // new photos together, so ordering here avoids a brief flash of
        // missing thumbnails.
        let sorted = batch.records.sorted { lhs, rhs in
            photoPriority(lhs.kind) < photoPriority(rhs.kind)
        }
        for record in sorted {
            switch record.kind {
            case .entry:
                await applyEntryUpsert(record)
            case .insight:
                await applyInsightUpsert(record)
            case .deleted:
                await applyTombstone(record)
            case .photo:
                await applyPhotoBlob(record)
            }
        }

        // Bare deletes arrive when a record was removed server-side
        // without a tombstone — for us, that's the pusher cleaning up
        // the original record after writing a tombstone. Ignore the
        // companion "-tombstone" cleanup too; the tombstone payload is
        // what drives the local delete.
        for id in batch.deletedRecordIDs where !id.hasSuffix("-tombstone") {
            if let uuid = UUID(uuidString: id) {
                try? await entries.delete(id: uuid)
                try? await insights.delete(id: uuid)
            }
        }
    }

    private nonisolated func photoPriority(_ kind: SyncRecordKind) -> Int {
        kind == .photo ? 0 : 1
    }

    private func applyEntryUpsert(_ record: SyncCloudRecord) async {
        do {
            let snapshot = try await codec.decodeEntry(record.ciphertext)
            if let local = try await entries.fetch(id: snapshot.id),
               local.updatedAt >= snapshot.updatedAt {
                // Local copy is newer (or same). Skip so we don't clobber
                // a user edit with an older remote version.
                return
            }
            try await entries.save(snapshot)
        } catch {
            MiraLog.logger(.general).error("Failed to apply entry upsert \(record.id): \(error.localizedDescription)")
        }
    }

    private func applyInsightUpsert(_ record: SyncCloudRecord) async {
        do {
            let snapshot = try await codec.decodeInsight(record.ciphertext)
            if let local = try await insights.fetch(id: snapshot.id),
               local.createdAt >= snapshot.createdAt {
                return
            }
            try await insights.save(snapshot)
        } catch {
            MiraLog.logger(.general).error("Failed to apply insight upsert \(record.id): \(error.localizedDescription)")
        }
    }

    private func applyPhotoBlob(_ record: SyncCloudRecord) async {
        do {
            let blob = try await codec.decodePhotoBlob(record.ciphertext)
            let relativePath = "Photos/\(blob.id.uuidString).jpg"
            // Skip the decrypt+write if we already have this blob on disk.
            // Saves a CPU hit during a full resync on a device that
            // already synced once.
            if await photos.exists(relativePath: relativePath) {
                return
            }
            guard let assetCiphertext = record.assetCiphertext else {
                MiraLog.logger(.general).error("Photo blob \(record.id) had no asset payload")
                return
            }
            let bytes = try await codec.openAsset(assetCiphertext)
            _ = try await photos.save(bytes, id: blob.id)
        } catch {
            MiraLog.logger(.general).error("Failed to apply photo blob \(record.id): \(error.localizedDescription)")
        }
    }

    private func applyTombstone(_ record: SyncCloudRecord) async {
        do {
            let tombstone = try await codec.decodeTombstone(record.ciphertext)
            switch tombstone.originalKind {
            case .entry:
                if let local = try await entries.fetch(id: tombstone.id),
                   local.updatedAt > tombstone.deletedAt {
                    // A later edit on some device outruns this delete —
                    // keep the entry.
                    return
                }
                try await entries.delete(id: tombstone.id)
            case .insight:
                if let local = try await insights.fetch(id: tombstone.id),
                   local.createdAt > tombstone.deletedAt {
                    return
                }
                try await insights.delete(id: tombstone.id)
            case .deleted, .photo:
                // Photo blobs have no tombstones in the current pipeline —
                // orphaned blobs in the user's private CK zone are cheap
                // and will be garbage-collected in a later pass.
                break
            }
        } catch {
            MiraLog.logger(.general).error("Failed to apply tombstone \(record.id): \(error.localizedDescription)")
        }
    }
}
