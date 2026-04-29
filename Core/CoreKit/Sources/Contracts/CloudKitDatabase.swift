import Foundation

/// Opaque CloudKit record payload used by the sync pipeline. The record
/// name is the entity UUID; `ciphertext` is the sealed envelope produced
/// by `SyncPayloadCodec`. Keeps CloudKit-specific types out of CoreKit.
///
/// `assetCiphertext` carries encrypted binary payloads that should be
/// written to a `CKAsset` field instead of the inline `ciphertext` blob
/// — currently populated only for `.photo` records so large JPEGs don't
/// blow past CloudKit's 1 MB per-record soft limit on the inline field.
public struct SyncCloudRecord: Sendable, Hashable {
    public let id: String
    public let kind: SyncRecordKind
    public let ciphertext: Data
    public let assetCiphertext: Data?
    public let updatedAt: Date

    public init(
        id: String,
        kind: SyncRecordKind,
        ciphertext: Data,
        assetCiphertext: Data? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.ciphertext = ciphertext
        self.assetCiphertext = assetCiphertext
        self.updatedAt = updatedAt
    }
}

/// Opaque wrapper around `CKServerChangeToken`. The underlying Data is
/// an archived `CKServerChangeToken`; shape is known only to the
/// CloudKit adapter. Persisted between launches so the puller can fetch
/// deltas instead of the whole zone on every run.
public struct CloudKitChangeToken: Sendable, Hashable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }
}

/// One batch from `CloudKitDatabase.fetchChanges`. `moreComing == true`
/// means the server paginated — keep calling with `newToken` until it
/// flips false.
public struct CloudKitPullBatch: Sendable {
    public let records: [SyncCloudRecord]
    public let deletedRecordIDs: [String]
    public let newToken: CloudKitChangeToken?
    public let moreComing: Bool

    public init(
        records: [SyncCloudRecord],
        deletedRecordIDs: [String],
        newToken: CloudKitChangeToken?,
        moreComing: Bool
    ) {
        self.records = records
        self.deletedRecordIDs = deletedRecordIDs
        self.newToken = newToken
        self.moreComing = moreComing
    }
}

/// Coarse-grained result of `CloudKitDatabase.accountStatus()`. Used
/// by the sync façade to bail out of enabling sync when the user isn't
/// signed into iCloud, so the UI can surface a useful message instead
/// of silently queueing pushes that will never go out.
public enum CloudKitAccountStatus: Sendable, Hashable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
}

public enum CloudKitPullError: Error, LocalizedError, Sendable {
    /// The saved change token was invalidated server-side (zone reset,
    /// token retention window exceeded). Caller must clear persisted
    /// token and re-fetch from nil for a full resync.
    case tokenExpired
    case transient(String)

    public var errorDescription: String? {
        switch self {
        case .tokenExpired:
            "CloudKit change token expired. Will reset on next pull."
        case .transient(let message):
            "CloudKit pull failed: \(message)"
        }
    }
}

/// Read/write side of CloudKit used by the sync pipeline. Production
/// is backed by `CKDatabase.privateCloudDatabase`; tests inject an
/// in-memory double.
public protocol CloudKitDatabase: Sendable {
    func save(_ records: [SyncCloudRecord]) async throws
    func delete(_ recordIDs: [String]) async throws
    func fetchChanges(since token: CloudKitChangeToken?) async throws -> CloudKitPullBatch

    /// Creates the silent-push subscriptions for Entry, Insight, and
    /// Deleted record types if they aren't already registered. Safe to
    /// call on every launch — subscriptions are keyed on stable IDs so
    /// CloudKit dedups. No-op in the in-memory test double.
    func ensureSubscriptions() async throws

    func accountStatus() async -> CloudKitAccountStatus
}
