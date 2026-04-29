import Foundation
import CoreKit

/// Dictionary-backed `CloudKitDatabase` for tests. Records last-write-wins
/// by id, exposes saved/deleted arrays so tests can assert what the
/// pusher pushed, and supports a `failNextSave` / `failNextDelete` flag
/// so retry behaviour can be driven deterministically.
///
/// The fake change-log implementation uses a monotonically increasing
/// integer stamp (stored in the opaque `CloudKitChangeToken.data` as a
/// UTF-8-encoded Int string) so the puller can fetch "everything since
/// stamp N" in tests without needing a real CKServerChangeToken.
public actor InMemoryCloudKitDatabase: CloudKitDatabase {
    public private(set) var records: [String: SyncCloudRecord] = [:]
    public private(set) var deletedIDs: [String] = []
    public private(set) var saveCalls: [[SyncCloudRecord]] = []
    public private(set) var deleteCalls: [[String]] = []
    public var failNextSave: Error?
    public var failNextDelete: Error?
    public var failNextFetch: Error?

    private struct LogEntry {
        let stamp: Int
        let record: SyncCloudRecord?
        let deletedID: String?
    }

    private var changeLog: [LogEntry] = []
    private var nextStamp: Int = 1

    public init() {}

    public func save(_ records: [SyncCloudRecord]) async throws {
        saveCalls.append(records)
        if let error = failNextSave {
            failNextSave = nil
            throw error
        }
        for record in records {
            self.records[record.id] = record
            changeLog.append(LogEntry(stamp: nextStamp, record: record, deletedID: nil))
            nextStamp += 1
        }
    }

    public func delete(_ recordIDs: [String]) async throws {
        deleteCalls.append(recordIDs)
        if let error = failNextDelete {
            failNextDelete = nil
            throw error
        }
        for id in recordIDs {
            records.removeValue(forKey: id)
            deletedIDs.append(id)
            changeLog.append(LogEntry(stamp: nextStamp, record: nil, deletedID: id))
            nextStamp += 1
        }
    }

    public func fetchChanges(since token: CloudKitChangeToken?) async throws -> CloudKitPullBatch {
        if let error = failNextFetch {
            failNextFetch = nil
            throw error
        }
        let sinceStamp = Self.decodeStamp(token) ?? 0
        let slice = changeLog.filter { $0.stamp > sinceStamp }
        let records = slice.compactMap(\.record)
        let deleted = slice.compactMap(\.deletedID)
        let latestStamp = slice.last?.stamp ?? sinceStamp
        let newToken = latestStamp > 0 ? Self.encodeStamp(latestStamp) : token
        return CloudKitPullBatch(records: records, deletedRecordIDs: deleted, newToken: newToken, moreComing: false)
    }

    public func setFailNextSave(_ error: Error?) {
        failNextSave = error
    }

    public func setFailNextDelete(_ error: Error?) {
        failNextDelete = error
    }

    public func setFailNextFetch(_ error: Error?) {
        failNextFetch = error
    }

    public private(set) var subscriptionCalls: Int = 0
    public var stubbedAccountStatus: CloudKitAccountStatus = .available

    public func ensureSubscriptions() async throws {
        subscriptionCalls += 1
    }

    public func accountStatus() async -> CloudKitAccountStatus {
        stubbedAccountStatus
    }

    public func setStubbedAccountStatus(_ status: CloudKitAccountStatus) {
        stubbedAccountStatus = status
    }

    /// Test helper — wipes the change log so a subsequent `fetchChanges`
    /// with the same token throws `.tokenExpired`. Useful for driving
    /// the resync path deterministically.
    public func simulateTokenExpiry() {
        changeLog.removeAll()
        nextStamp = 1
    }

    private static func encodeStamp(_ stamp: Int) -> CloudKitChangeToken {
        CloudKitChangeToken(data: Data(String(stamp).utf8))
    }

    private static func decodeStamp(_ token: CloudKitChangeToken?) -> Int? {
        guard let token,
              let string = String(data: token.data, encoding: .utf8),
              let value = Int(string) else {
            return nil
        }
        return value
    }
}
