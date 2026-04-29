import Foundation
import Testing
import CoreKit
import TestSupport
@testable import Utilities

@Suite("Utilities smoke")
struct UtilitiesSmokeTests {
    @Test("MiraLog returns logger with stable subsystem")
    func loggerSubsystem() {
        let logger = MiraLog.logger(.general)
        // Logger has no public API to inspect subsystem; just exercise the
        // factory to make sure it compiles and runs.
        logger.debug("smoke")
    }

    @Test("KeychainStore initialises with a service identifier")
    func keychainInit() async {
        let store = KeychainStore(service: "com.veilbytesoft.Mira.tests")
        _ = store
    }

    @Test("SecretStore round-trips values via default (non-sync) slot")
    func secretStoreRoundTripLocal() async throws {
        let store = InMemorySecretStore()
        try await store.setString("value-local", for: "round-trip")
        #expect(try await store.string(for: "round-trip") == "value-local")
        try await store.remove("round-trip")
        #expect(try await store.string(for: "round-trip") == nil)
    }

    @Test("Non-sync and sync slots are isolated")
    func secretStoreSlotsIsolated() async throws {
        let store = InMemorySecretStore()
        try await store.setString("local", for: "isolation", synchronizable: false)
        try await store.setString("sync", for: "isolation", synchronizable: true)

        #expect(try await store.string(for: "isolation", synchronizable: false) == "local")
        #expect(try await store.string(for: "isolation", synchronizable: true) == "sync")

        try await store.remove("isolation", synchronizable: true)
        #expect(try await store.string(for: "isolation", synchronizable: true) == nil)
        #expect(try await store.string(for: "isolation", synchronizable: false) == "local")
    }

    @Test("SyncEncryption seals new key into synced slot and round-trips")
    func syncEncryptionFreshRoundTrip() async throws {
        let store = InMemorySecretStore()
        let encryption = SyncEncryption(store: store)

        let plaintext = Data("hello mira".utf8)
        let sealed = try await encryption.seal(plaintext)
        #expect(sealed != plaintext)
        #expect(try await encryption.open(sealed) == plaintext)

        // Key lives in the synced slot, not the device-only one.
        #expect(try await store.string(for: SyncEncryption.keyAccount, synchronizable: true) != nil)
        #expect(try await store.string(for: SyncEncryption.keyAccount, synchronizable: false) == nil)
    }

    @Test("SyncEncryption migrates legacy device-only key into synced slot")
    func syncEncryptionMigratesLegacyKey() async throws {
        let store = InMemorySecretStore()
        // Simulate a legacy install: key written to the non-sync slot.
        let legacyEncoded = Data((0..<32).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
        try await store.setString(legacyEncoded, for: SyncEncryption.keyAccount, synchronizable: false)

        let encryption = SyncEncryption(store: store)
        _ = try await encryption.seal(Data("x".utf8))

        #expect(try await store.string(for: SyncEncryption.keyAccount, synchronizable: true) == legacyEncoded)
        #expect(try await store.string(for: SyncEncryption.keyAccount, synchronizable: false) == nil)
    }

    @Test("SyncEncryption.rotateKey wipes both slots")
    func syncEncryptionRotateKey() async throws {
        let store = InMemorySecretStore()
        let encryption = SyncEncryption(store: store)
        _ = try await encryption.seal(Data("x".utf8))
        #expect(try await store.string(for: SyncEncryption.keyAccount, synchronizable: true) != nil)

        try await encryption.rotateKey()
        #expect(try await store.string(for: SyncEncryption.keyAccount, synchronizable: true) == nil)
        #expect(try await store.string(for: SyncEncryption.keyAccount, synchronizable: false) == nil)
    }

    @Test("SyncPayloadCodec round-trips EntrySnapshot through sealed envelope")
    func syncCodecEntryRoundTrip() async throws {
        let encryption = SyncEncryption(store: InMemorySecretStore())
        let codec = SyncPayloadCodec(encryption: encryption)
        let photo = PhotoAssetSnapshot(id: UUID(), relativePath: "Photos/a.jpg", createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let original = EntrySnapshot(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500),
            content: "hello",
            mood: .neutral,
            tags: ["t"],
            photos: [photo]
        )
        let ciphertext = try await codec.encode(original)
        let decoded = try await codec.decodeEntry(ciphertext)
        #expect(decoded == original)
    }

    @Test("SyncPayloadCodec round-trips InsightSnapshot through sealed envelope")
    func syncCodecInsightRoundTrip() async throws {
        let encryption = SyncEncryption(store: InMemorySecretStore())
        let codec = SyncPayloadCodec(encryption: encryption)
        let original = InsightSnapshot(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .weeklyReflection,
            title: "Week of April 20",
            body: "…",
            referencedEntryIDs: [UUID()]
        )
        let ciphertext = try await codec.encode(original)
        let decoded = try await codec.decodeInsight(ciphertext)
        #expect(decoded == original)
    }

    @Test("SyncPayloadCodec rejects kind mismatch")
    func syncCodecKindMismatch() async throws {
        let encryption = SyncEncryption(store: InMemorySecretStore())
        let codec = SyncPayloadCodec(encryption: encryption)
        let entryCiphertext = try await codec.encode(EntrySnapshot(content: "x"))
        await #expect(throws: SyncCodecError.self) {
            _ = try await codec.decodeInsight(entryCiphertext)
        }
    }
}
