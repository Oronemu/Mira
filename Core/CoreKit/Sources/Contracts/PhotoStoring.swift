import Foundation

/// Persists photo bytes outside SwiftData (the database holds metadata
/// only). Implemented by `Utilities.PhotoStorageService`; tests inject
/// `MockPhotoStoring` from TestSupport.
public protocol PhotoStoring: Sendable {
    /// Persist `data` and return metadata that callers can attach to an
    /// `EntrySnapshot` and round-trip through the repository.
    func save(_ data: Data) async throws -> PhotoAssetSnapshot

    /// Persist `data` at the deterministic path owned by `id`, overwriting
    /// whatever was there. Used by the sync puller to materialise a photo
    /// downloaded from CloudKit under the same relative path every device
    /// will resolve from `PhotoAssetSnapshot.id`.
    func save(_ data: Data, id: UUID) async throws -> PhotoAssetSnapshot

    /// Reports whether a file exists at the given relative path. Lets the
    /// puller skip the CloudKit round-trip when the blob is already on disk.
    func exists(relativePath: String) async -> Bool

    func read(relativePath: String) async throws -> Data
    func delete(relativePath: String) async throws
}
