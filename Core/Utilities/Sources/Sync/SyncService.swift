import Foundation
import CoreKit

public enum SyncStatus: Sendable, Hashable {
    case idle
    case syncing
    case succeeded(Date)
    case failed(String)
}

/// Top-level façade for the iCloud sync feature. Owns the pusher,
/// puller, pending-push queue, and change-token store; exposes the
/// trio the settings UI drives: `setEnabled`, `sync()`, `reset()`.
///
/// When constructed without `Components` (default init — used by
/// previews, unimplemented injection, and test harnesses that don't
/// care about sync), `sync()` is a no-op that records `.succeeded`
/// so the UI path stays non-fatal.
public actor SyncService {
    public private(set) var status: SyncStatus = .idle
    private let components: Components?
    private let encryption: SyncEncryption
    private var statusObservers: [UUID: AsyncStream<SyncStatus>.Continuation] = [:]

    public struct Components: Sendable {
        public let database: any CloudKitDatabase
        public let pusher: CloudKitPusher
        public let puller: CloudKitPuller
        public let queue: PendingPushQueue
        public let tokens: ChangeTokenStore

        public init(
            database: any CloudKitDatabase,
            pusher: CloudKitPusher,
            puller: CloudKitPuller,
            queue: PendingPushQueue,
            tokens: ChangeTokenStore
        ) {
            self.database = database
            self.pusher = pusher
            self.puller = puller
            self.queue = queue
            self.tokens = tokens
        }
    }

    private let defaults: UserDefaults
    private static let photoBackfillFlag = "mira.sync.photoBlobBackfill.v1"
    private static let customStickerBackfillFlag = "mira.sync.customStickerBlobBackfill.v1"

    public init(
        encryption: SyncEncryption = SyncEncryption(),
        components: Components? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.encryption = encryption
        self.components = components
        self.defaults = defaults
    }

    /// Reports whether the current iCloud account can take sync. When
    /// components aren't wired (preview / stub mode), returns
    /// `.available` so the UI doesn't gate on a non-existent check.
    public func accountStatus() async -> CloudKitAccountStatus {
        guard let components else { return .available }
        return await components.database.accountStatus()
    }

    /// Flipping the toggle on starts the pusher's change-stream observer
    /// and runs an initial sync. Flipping off stops the observer,
    /// rotates the encryption key, and clears state so a later re-enable
    /// starts from scratch.
    public func setEnabled(_ enabled: Bool) async {
        guard let components else { return }
        if enabled {
            // Registering subscriptions is idempotent but needs to happen
            // at least once per install so silent pushes start flowing
            // when another device writes a record.
            do {
                try await components.database.ensureSubscriptions()
            } catch {
                MiraLog.logger(.general).error("CloudKit subscription setup failed: \(error.localizedDescription)")
            }
            await components.pusher.start()
            await sync()
        } else {
            await components.pusher.stop()
            await reset()
        }
    }

    /// Runs a single push + pull cycle on demand. Failures are captured
    /// in `status` and the next run will retry.
    public func sync() async {
        setStatus(.syncing)
        guard let components else {
            setStatus(.succeeded(.now))
            return
        }
        await runPhotoBackfillIfNeeded()
        await runCustomStickerBackfillIfNeeded()
        // Push first so a fresh device's pull sees what this device
        // generated locally before the new remote state arrives.
        await components.pusher.flushOnce()
        await components.puller.pullOnce()
        setStatus(.succeeded(.now))
    }

    /// Ships photos attached to entries that existed before this build
    /// added photo-blob sync. Runs at most once per install, gated by a
    /// flag in `UserDefaults` so re-triggering `sync()` doesn't repeat
    /// the walk.
    private func runPhotoBackfillIfNeeded() async {
        guard let components else { return }
        guard !defaults.bool(forKey: Self.photoBackfillFlag) else { return }
        await components.pusher.backfillPhotoBlobs()
        defaults.set(true, forKey: Self.photoBackfillFlag)
    }

    /// Ships user-created stickers that existed before the sticker sync
    /// pipeline shipped. Same one-shot gating as the photo backfill.
    private func runCustomStickerBackfillIfNeeded() async {
        guard let components else { return }
        guard !defaults.bool(forKey: Self.customStickerBackfillFlag) else { return }
        await components.pusher.backfillCustomStickerBlobs()
        defaults.set(true, forKey: Self.customStickerBackfillFlag)
    }

    /// Stops pushes, wipes the change token, rotates the encryption
    /// key, and drops anything queued. Safe to call whether or not
    /// components are wired.
    public func reset() async {
        setStatus(.idle)
        // Clear the backfill flags so a later re-enable re-uploads every
        // photo / user sticker under a freshly rotated key — skipping
        // this would leave blobs in the cloud that the new key can't
        // decrypt.
        defaults.removeObject(forKey: Self.photoBackfillFlag)
        defaults.removeObject(forKey: Self.customStickerBackfillFlag)
        guard let components else {
            try? await encryption.rotateKey()
            return
        }
        await components.pusher.stop()
        await components.tokens.clear()
        try? await encryption.rotateKey()
        let pendingIDs = await components.queue.snapshot.map(\.id)
        try? await components.queue.markCompleted(pendingIDs)
    }

    /// Continuous stream of status transitions. Each subscriber receives
    /// the current status on subscription, then every subsequent change.
    /// UI consumers (e.g. a small "Syncing…" badge on the journal
    /// screen) drive off this instead of polling `status`.
    public nonisolated func statusStream() -> AsyncStream<SyncStatus> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.registerStatusObserver(token: token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterStatusObserver(token: token) }
            }
        }
    }

    private func registerStatusObserver(
        token: UUID,
        continuation: AsyncStream<SyncStatus>.Continuation
    ) {
        statusObservers[token] = continuation
        continuation.yield(status)
    }

    private func unregisterStatusObserver(token: UUID) {
        statusObservers.removeValue(forKey: token)
    }

    private func setStatus(_ newValue: SyncStatus) {
        status = newValue
        for continuation in statusObservers.values {
            continuation.yield(newValue)
        }
    }
}
