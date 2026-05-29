import Foundation

/// Kind marker carried by every `SyncEnvelope`. Maps 1:1 to the
/// CloudKit record type that wraps the ciphertext.
public enum SyncRecordKind: String, Sendable, Hashable, Codable {
    case entry
    case insight
    case deleted
    /// Encrypted binary asset attached to an entry (photo bytes).
    /// Carried in CloudKit as a separate `PhotoBlob` record so large
    /// binary payloads ride in a `CKAsset` field instead of inflating
    /// the entry record's ciphertext.
    case photo
    /// Encrypted PNG bytes for a user-created sticker (subject lifted
    /// from a photo). Like `photo`, the bytes ride in a `CKAsset`
    /// field on a `UserStickerBlob` record so the entry envelope only
    /// carries the `libraryRef`.
    case userSticker
}
