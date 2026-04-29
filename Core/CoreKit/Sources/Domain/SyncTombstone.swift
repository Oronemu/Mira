import Foundation

/// Marker record written to CloudKit when an entity is deleted. Other
/// devices learn about the delete by reading these tombstones on pull —
/// without them, the pull side can't tell "record was deleted" from
/// "record was never synced". `originalKind` tells the puller which
/// local table to prune.
public struct SyncTombstone: Codable, Sendable, Hashable {
    public let id: UUID
    public let originalKind: SyncRecordKind
    public let deletedAt: Date

    public init(id: UUID, originalKind: SyncRecordKind, deletedAt: Date) {
        self.id = id
        self.originalKind = originalKind
        self.deletedAt = deletedAt
    }
}
