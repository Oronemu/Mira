import Foundation

/// Immutable, Sendable handle to a photo persisted on disk.
/// `relativePath` is rooted at the app container's `Photos/` directory;
/// `Utilities.PhotoStorageService` resolves it to bytes.
public struct PhotoAssetSnapshot: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let relativePath: String
    public let createdAt: Date

    public init(id: UUID = UUID(), relativePath: String, createdAt: Date = .now) {
        self.id = id
        self.relativePath = relativePath
        self.createdAt = createdAt
    }
}
