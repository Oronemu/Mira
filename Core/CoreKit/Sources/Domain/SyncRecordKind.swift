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
}
