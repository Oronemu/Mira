import Foundation

/// Metadata envelope for a user-sticker's encrypted PNG pushed to
/// CloudKit. Mirrors `PhotoBlobSnapshot`: bytes ride in a `CKAsset` on
/// the same `UserStickerBlob` record, this struct decodes from the
/// inline ciphertext and gives future schema versions a place to hang
/// extra per-sticker fields.
public struct CustomStickerBlobSnapshot: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let createdAt: Date

    public init(id: UUID, createdAt: Date) {
        self.id = id
        self.createdAt = createdAt
    }
}
