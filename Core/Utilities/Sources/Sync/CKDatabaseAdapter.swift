import Foundation
import CloudKit
import CoreKit

/// Thin adapter mapping `SyncCloudRecord` into CloudKit's record model.
/// Record type names mirror the domain (`Entry`, `Insight`, `Deleted`);
/// the record name is the entity UUID so pushes are idempotent and
/// compatible with server change tokens on pull. Schema is created
/// on-demand in the CloudKit Development environment; remember to
/// "Deploy to Production" in CloudKit Dashboard before shipping.
public actor CKDatabaseAdapter: CloudKitDatabase {
    /// Name of the custom zone we create inside the user's private
    /// database. We can't use the default zone because
    /// `CKFetchRecordZoneChangesOperation` — the puller's engine —
    /// only supports custom zones for delta fetches.
    public static let defaultZoneName = "MiraSync"

    private let container: CKContainer?
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    private var zoneEnsured = false

    public init(
        container: CKContainer?,
        database: CKDatabase,
        zoneID: CKRecordZone.ID = CKRecordZone.ID(
            zoneName: CKDatabaseAdapter.defaultZoneName,
            ownerName: CKCurrentUserDefaultName
        )
    ) {
        self.container = container
        self.database = database
        self.zoneID = zoneID
    }

    public init(containerIdentifier: String) {
        let container = CKContainer(identifier: containerIdentifier)
        self.init(container: container, database: container.privateCloudDatabase)
    }

    public func save(_ records: [SyncCloudRecord]) async throws {
        guard !records.isEmpty else { return }
        try await ensureZoneIfNeeded()
        // CKAsset needs a real file URL, so asset-bearing records stage
        // their ciphertext into a temp file before the save. The URL is
        // captured so we can clean up after the operation completes —
        // CloudKit copies the bytes off the URL synchronously during the
        // save request.
        let prepared = try records.map { try Self.makeCKRecord($0, zoneID: zoneID) }
        let tempURLs = prepared.compactMap(\.tempURL)
        defer {
            for url in tempURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }
        let ckRecords = prepared.map(\.record)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: ckRecords, recordIDsToDelete: nil)
            op.savePolicy = .changedKeys
            op.isAtomic = false
            op.qualityOfService = .userInitiated
            // Per-record outcome — with isAtomic=false the operation block
            // reports overall success even if individual records fail.
            op.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success(let record):
                    MiraLog.logger(.general).info("Sync: per-record save OK \(record.recordType, privacy: .public) \(recordID.recordName, privacy: .public)")
                case .failure(let error):
                    let ck = error as? CKError
                    let code = ck.map { "CKError.\($0.code.rawValue)" } ?? "\((error as NSError).domain)#\((error as NSError).code)"
                    MiraLog.logger(.general).error("Sync: per-record save FAILED \(recordID.recordName, privacy: .public) — \(code, privacy: .public) \(error.localizedDescription, privacy: .public)")
                }
            }
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error):
                    Self.log(error: error, operation: "save")
                    continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }

    public func delete(_ recordIDs: [String]) async throws {
        guard !recordIDs.isEmpty else { return }
        try await ensureZoneIfNeeded()
        let ids = recordIDs.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
            op.isAtomic = false
            op.qualityOfService = .userInitiated
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error):
                    Self.log(error: error, operation: "delete")
                    continuation.resume(throwing: error)
                }
            }
            database.add(op)
        }
    }

    /// Lazily creates the custom record zone on first operation. CloudKit
    /// happily reports "already exists" when we try to create twice, so
    /// the `zoneEnsured` flag just skips the round-trip on subsequent
    /// calls within the same process.
    private func ensureZoneIfNeeded() async throws {
        guard !zoneEnsured else { return }
        let zone = CKRecordZone(zoneID: zoneID)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKModifyRecordZonesOperation(
                recordZonesToSave: [zone],
                recordZoneIDsToDelete: nil
            )
            op.qualityOfService = .userInitiated
            op.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    // "Already exists" is the expected path on every
                    // launch after the first — treat as success.
                    if let ck = error as? CKError,
                       ck.code == .serverRejectedRequest || ck.code == .unknownItem {
                        continuation.resume()
                    } else {
                        Self.log(error: error, operation: "ensureZone")
                        continuation.resume(throwing: error)
                    }
                }
            }
            database.add(op)
        }
        zoneEnsured = true
    }

    private static func log(error: Error, operation: String) {
        if let ck = error as? CKError {
            MiraLog.logger(.general).error("CloudKit \(operation) failed: CKError.\(ck.code.rawValue) \(ck.localizedDescription)")
        } else {
            let nsError = error as NSError
            MiraLog.logger(.general).error("CloudKit \(operation) failed: \(nsError.domain)#\(nsError.code) \(nsError.localizedDescription)")
        }
    }

    public func fetchChanges(since token: CloudKitChangeToken?) async throws -> CloudKitPullBatch {
        try await ensureZoneIfNeeded()
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        if let token, let ck = try? Self.decodeToken(token) {
            config.previousServerChangeToken = ck
        }

        let collector = Collector()
        let capturedZone = zoneID

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [capturedZone],
                configurationsByRecordZoneID: [capturedZone: config]
            )
            op.qualityOfService = .userInitiated
            op.fetchAllChanges = true

            op.recordWasChangedBlock = { _, result in
                if case .success(let record) = result,
                   let decoded = Self.decodeRecord(record) {
                    collector.append(record: decoded)
                }
            }
            op.recordWithIDWasDeletedBlock = { id, _ in
                collector.append(deletedID: id.recordName)
            }
            op.recordZoneChangeTokensUpdatedBlock = { _, newTokenOpt, _ in
                if let newTokenOpt, let encoded = try? Self.encodeToken(newTokenOpt) {
                    collector.setToken(encoded)
                }
            }
            op.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success(let info):
                    if let encoded = try? Self.encodeToken(info.serverChangeToken) {
                        collector.setToken(encoded)
                    }
                    collector.setMoreComing(info.moreComing)
                case .failure(let error):
                    collector.setZoneError(error)
                }
            }
            op.fetchRecordZoneChangesResultBlock = { result in
                if let err = collector.zoneError {
                    Self.log(error: err, operation: "fetchChanges(zone)")
                    if let ck = err as? CKError, ck.code == .changeTokenExpired {
                        continuation.resume(throwing: CloudKitPullError.tokenExpired)
                    } else {
                        continuation.resume(throwing: CloudKitPullError.transient(Self.describe(err)))
                    }
                    return
                }
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    Self.log(error: error, operation: "fetchChanges")
                    continuation.resume(throwing: CloudKitPullError.transient(Self.describe(error)))
                }
            }
            database.add(op)
        }

        return collector.snapshot()
    }

    private static func describe(_ error: Error) -> String {
        if let ck = error as? CKError {
            return "CKError.\(ck.code.rawValue) — \(ck.localizedDescription)"
        }
        let nsError = error as NSError
        return "\(nsError.domain)#\(nsError.code) — \(nsError.localizedDescription)"
    }

    private final class Collector: @unchecked Sendable {
        private var records: [SyncCloudRecord] = []
        private var deletedIDs: [String] = []
        private var token: CloudKitChangeToken?
        private var moreComing = false
        private(set) var zoneError: Error?

        func append(record: SyncCloudRecord) { records.append(record) }
        func append(deletedID: String) { deletedIDs.append(deletedID) }
        func setToken(_ newToken: CloudKitChangeToken) { token = newToken }
        func setMoreComing(_ value: Bool) { moreComing = value }
        func setZoneError(_ error: Error) { zoneError = error }

        func snapshot() -> CloudKitPullBatch {
            CloudKitPullBatch(
                records: records,
                deletedRecordIDs: deletedIDs,
                newToken: token,
                moreComing: moreComing
            )
        }
    }

    private static func makeCKRecord(
        _ record: SyncCloudRecord,
        zoneID: CKRecordZone.ID
    ) throws -> (record: CKRecord, tempURL: URL?) {
        let recordID = CKRecord.ID(recordName: record.id, zoneID: zoneID)
        let ck = CKRecord(recordType: recordType(for: record.kind), recordID: recordID)
        ck["ciphertext"] = record.ciphertext as NSData
        ck["updatedAt"] = record.updatedAt as NSDate
        ck["kind"] = record.kind.rawValue as NSString
        ck["schemaVersion"] = NSNumber(value: SyncSchemaVersion.current)
        var tempURL: URL?
        if let assetCiphertext = record.assetCiphertext {
            let url = try writeAssetTempFile(data: assetCiphertext, recordID: recordID.recordName)
            ck["asset"] = CKAsset(fileURL: url)
            tempURL = url
        }
        return (ck, tempURL)
    }

    private static func writeAssetTempFile(data: Data, recordID: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiraSyncAssets", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(recordID)-\(UUID().uuidString).bin")
        try data.write(to: url, options: .atomic)
        return url
    }

    public func accountStatus() async -> CloudKitAccountStatus {
        guard let container else { return .available }
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .temporarilyUnavailable: return .temporarilyUnavailable
            case .couldNotDetermine: return .couldNotDetermine
            @unknown default: return .couldNotDetermine
            }
        } catch {
            return .couldNotDetermine
        }
    }

    public func ensureSubscriptions() async throws {
        let kinds: [(SyncRecordKind, String)] = [
            (.entry, "Entry"),
            (.insight, "Insight"),
            (.deleted, "Deleted"),
            (.photo, "PhotoBlob"),
            (.userSticker, "UserStickerBlob"),
        ]
        let subscriptions: [CKSubscription] = kinds.map { kind, recordType in
            let subscriptionID = "sync.subscription.\(kind.rawValue).v1"
            let sub = CKQuerySubscription(
                recordType: recordType,
                predicate: NSPredicate(value: true),
                subscriptionID: subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            let info = CKSubscription.NotificationInfo()
            // Silent push: no banner, no sound, just wakes the app in
            // background to call syncNow().
            info.shouldSendContentAvailable = true
            sub.notificationInfo = info
            return sub
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKModifySubscriptionsOperation(
                subscriptionsToSave: subscriptions,
                subscriptionIDsToDelete: nil
            )
            op.qualityOfService = .utility
            op.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error):
                    // "already exists" is benign — idempotent setup.
                    if let ck = error as? CKError, ck.code == .serverRejectedRequest {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
            database.add(op)
        }
    }

    private static func recordType(for kind: SyncRecordKind) -> String {
        switch kind {
        case .entry: "Entry"
        case .insight: "Insight"
        case .deleted: "Deleted"
        case .photo: "PhotoBlob"
        case .userSticker: "UserStickerBlob"
        }
    }

    private static func decodeRecord(_ ck: CKRecord) -> SyncCloudRecord? {
        guard let ciphertext = ck["ciphertext"] as? Data,
              let updatedAt = ck["updatedAt"] as? Date,
              let kindRaw = ck["kind"] as? String,
              let kind = SyncRecordKind(rawValue: kindRaw) else {
            return nil
        }
        var assetCiphertext: Data?
        if let asset = ck["asset"] as? CKAsset, let url = asset.fileURL {
            // Read eagerly: CloudKit's cached asset file lives past this
            // callback, but later stages of the puller shuttle the bytes
            // across actor hops, and we don't want to rely on the URL
            // still being valid by the time they're needed.
            assetCiphertext = try? Data(contentsOf: url)
        }
        return SyncCloudRecord(
            id: ck.recordID.recordName,
            kind: kind,
            ciphertext: ciphertext,
            assetCiphertext: assetCiphertext,
            updatedAt: updatedAt
        )
    }

    private static func encodeToken(_ token: CKServerChangeToken) throws -> CloudKitChangeToken {
        let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        return CloudKitChangeToken(data: data)
    }

    private static func decodeToken(_ token: CloudKitChangeToken) throws -> CKServerChangeToken {
        guard let decoded = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: CKServerChangeToken.self,
            from: token.data
        ) else {
            throw CocoaError(.coderReadCorrupt)
        }
        return decoded
    }
}
