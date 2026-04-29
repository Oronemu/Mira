import Foundation
import Testing
import CoreKit
import TestSupport
@testable import Utilities

@Suite("Photo blob sync")
struct PhotoBlobSyncTests {
    @Test("SyncPayloadCodec round-trips PhotoBlobSnapshot")
    func codecRoundTrip() async throws {
        let encryption = SyncEncryption(store: InMemorySecretStore())
        let codec = SyncPayloadCodec(encryption: encryption)
        let blob = PhotoBlobSnapshot(id: UUID(), createdAt: Date(timeIntervalSince1970: 1_700_000_000))

        let ciphertext = try await codec.encode(blob)
        let decoded = try await codec.decodePhotoBlob(ciphertext)

        #expect(decoded == blob)
    }

    @Test("sealAsset / openAsset round-trip raw bytes")
    func assetSealRoundTrip() async throws {
        let encryption = SyncEncryption(store: InMemorySecretStore())
        let codec = SyncPayloadCodec(encryption: encryption)
        let bytes = Data(repeating: 0xAB, count: 4_096)

        let sealed = try await codec.sealAsset(bytes)
        #expect(sealed != bytes)
        #expect(try await codec.openAsset(sealed) == bytes)
    }

    @Test("push then pull reconstructs photo bytes on a second device")
    func pushPullReconstructsPhoto() async throws {
        let photoID = UUID()
        let entryID = UUID()
        let jpegBytes = Data((0..<1024).map { UInt8($0 % 251) })

        // --- Device A: repository holds an entry with a photo snapshot
        //     pointing at the canonical path; the local photo store has
        //     the bytes on disk.
        let deviceAPhotos = MockPhotoStoring()
        _ = try await deviceAPhotos.save(jpegBytes, id: photoID)
        let entrySnapshot = EntrySnapshot(
            id: entryID,
            createdAt: .init(timeIntervalSince1970: 1_700_000_000),
            updatedAt: .init(timeIntervalSince1970: 1_700_000_100),
            plainContent: "entry with a photo",
            photos: [PhotoAssetSnapshot(id: photoID, relativePath: "Photos/\(photoID.uuidString).jpg")]
        )
        let deviceAEntries = StubEntryRepository(stored: [entrySnapshot])
        let deviceAInsights = StubInsightRepository()

        let database = InMemoryCloudKitDatabase()
        let encryption = SyncEncryption(store: InMemorySecretStore())
        let codec = SyncPayloadCodec(encryption: encryption)
        let queueDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoBlobSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: queueDir, withIntermediateDirectories: true)
        let queue = try PendingPushQueue(url: queueDir.appendingPathComponent("queue.json"))

        let pusher = CloudKitPusher(
            database: database,
            codec: codec,
            queue: queue,
            entries: deviceAEntries,
            insights: deviceAInsights,
            photos: deviceAPhotos
        )
        await pusher.enqueueEntry(.upserted(entrySnapshot))
        await pusher.flushOnce()

        // Entry and photo blob both landed in the cloud.
        #expect(await database.records.count == 2)

        // --- Device B: fresh repo and photo store. Puller should
        //     materialise both the entry and the photo bytes at the
        //     expected relative path.
        let deviceBPhotos = MockPhotoStoring()
        let deviceBEntries = StubEntryRepository()
        let deviceBInsights = StubInsightRepository()
        let puller = CloudKitPuller(
            database: database,
            codec: codec,
            tokens: ChangeTokenStore.ephemeral(),
            entries: deviceBEntries,
            insights: deviceBInsights,
            photos: deviceBPhotos
        )
        await puller.pullOnce()

        let restored = try await deviceBEntries.fetch(id: entryID)
        #expect(restored?.photos.count == 1)
        let pulled = try await deviceBPhotos.read(
            relativePath: "Photos/\(photoID.uuidString).jpg"
        )
        #expect(pulled == jpegBytes)
    }

    @Test("puller skips decrypt when photo already on disk")
    func pullerSkipsExistingBlob() async throws {
        let photoID = UUID()
        let existing = Data("already-here".utf8)

        let deviceBPhotos = MockPhotoStoring()
        _ = try await deviceBPhotos.save(existing, id: photoID)

        // Craft a photo-only record in the in-memory DB that would
        // decrypt to different bytes — the puller should not touch it.
        let database = InMemoryCloudKitDatabase()
        let encryption = SyncEncryption(store: InMemorySecretStore())
        let codec = SyncPayloadCodec(encryption: encryption)
        let envelope = try await codec.encode(PhotoBlobSnapshot(id: photoID, createdAt: .now))
        let sealedBytes = try await codec.sealAsset(Data("other".utf8))
        try await database.save([
            SyncCloudRecord(
                id: CloudKitPusher.photoRecordID(for: photoID),
                kind: .photo,
                ciphertext: envelope,
                assetCiphertext: sealedBytes,
                updatedAt: .now
            )
        ])

        let puller = CloudKitPuller(
            database: database,
            codec: codec,
            tokens: ChangeTokenStore.ephemeral(),
            entries: StubEntryRepository(),
            insights: StubInsightRepository(),
            photos: deviceBPhotos
        )
        await puller.pullOnce()

        let stillThere = try await deviceBPhotos.read(
            relativePath: "Photos/\(photoID.uuidString).jpg"
        )
        #expect(stillThere == existing)
    }
}

// MARK: - Test helpers

private extension ChangeTokenStore {
    static func ephemeral() -> ChangeTokenStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoBlobSyncTests-token-\(UUID().uuidString).bin")
        return try! ChangeTokenStore(url: url)
    }
}

private actor StubEntryRepository: EntryRepository {
    private var entries: [UUID: EntrySnapshot] = [:]
    private var continuations: [UUID: AsyncStream<EntryChange>.Continuation] = [:]

    init(stored: [EntrySnapshot] = []) {
        for entry in stored { entries[entry.id] = entry }
    }

    func fetch(matching query: EntryQuery) async throws -> [EntrySnapshot] {
        Array(entries.values).sorted { $0.createdAt < $1.createdAt }
    }

    func fetch(id: UUID) async throws -> EntrySnapshot? { entries[id] }

    func save(_ entry: EntrySnapshot) async throws {
        entries[entry.id] = entry
        for continuation in continuations.values {
            continuation.yield(.upserted(entry))
        }
    }

    func delete(id: UUID) async throws {
        entries.removeValue(forKey: id)
        for continuation in continuations.values {
            continuation.yield(.deleted(id))
        }
    }

    nonisolated func observe(query: EntryQuery) -> AsyncStream<[EntrySnapshot]> {
        AsyncStream { _ in }
    }

    nonisolated func changes() -> AsyncStream<EntryChange> {
        AsyncStream { _ in }
    }

    func fetchUnindexed(limit: Int) async throws -> [UnindexedEntry] { [] }
    func updateEmbedding(id: UUID, data: Data?) async throws {}
    func fetchEmbedded() async throws -> [EmbeddedEntry] { [] }
    func recentTags(limit: Int) async throws -> [String] { [] }
}

private actor StubInsightRepository: InsightRepository {
    func fetchAll() async throws -> [InsightSnapshot] { [] }
    func fetch(id: UUID) async throws -> InsightSnapshot? { nil }
    func save(_ insight: InsightSnapshot) async throws {}
    func delete(id: UUID) async throws {}
    nonisolated func observeAll() -> AsyncStream<[InsightSnapshot]> { AsyncStream { _ in } }
    nonisolated func changes() -> AsyncStream<InsightChange> { AsyncStream { _ in } }
}
