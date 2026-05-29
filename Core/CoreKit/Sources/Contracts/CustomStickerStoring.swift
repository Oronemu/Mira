import Foundation

/// Persists user-created sticker PNGs outside SwiftData and feeds the
/// sync pusher with create/delete events. Implemented by
/// `Utilities.CustomStickerStorageService`; tests inject an in-memory
/// mock.
///
/// Encoding contract: callers pass already-PNG bytes (alpha preserved
/// from background removal). The store does not re-encode — the bytes
/// it returns from `read` are the exact bytes saved.
public protocol CustomStickerStoring: Sendable {
    /// Persist `pngData` and return the asset metadata. Generates a new
    /// UUID and emits `.upserted` on the change stream.
    @discardableResult
    func save(_ pngData: Data) async throws -> CustomStickerAsset

    /// Persist `pngData` at the deterministic path owned by `id`,
    /// overwriting whatever was there. Used by the sync puller to
    /// materialise bytes downloaded from CloudKit under the same
    /// relative path every device resolves the id to.
    @discardableResult
    func save(_ pngData: Data, id: UUID, createdAt: Date) async throws -> CustomStickerAsset

    /// Whether the file backing `id` exists locally. Lets the puller
    /// short-circuit when the blob is already on disk.
    func exists(id: UUID) async -> Bool

    func read(relativePath: String) async throws -> Data

    /// Delete the file for `id`. Emits `.deleted` on the change stream.
    func delete(id: UUID) async throws

    /// All known user stickers, newest first.
    func list() async throws -> [CustomStickerAsset]

    /// Long-lived stream of create/delete events. The sync pusher
    /// subscribes from `.task` so user-sticker changes propagate to
    /// CloudKit on the next debounce tick. Each subscriber receives
    /// events emitted after subscription.
    func changes() -> AsyncStream<CustomStickerChange>
}
