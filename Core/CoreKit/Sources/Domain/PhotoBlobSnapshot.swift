import Foundation

/// Metadata envelope for a photo's encrypted bytes pushed to CloudKit.
/// Real photo bytes ride in a separate `CKAsset` field on the same
/// CloudKit record — this struct is what the envelope's ciphertext
/// decodes to, giving future schema versions a handle to hang extra
/// per-blob fields (original size, checksum, EXIF strip marker, …).
public struct PhotoBlobSnapshot: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let createdAt: Date

    public init(id: UUID, createdAt: Date) {
        self.id = id
        self.createdAt = createdAt
    }
}
