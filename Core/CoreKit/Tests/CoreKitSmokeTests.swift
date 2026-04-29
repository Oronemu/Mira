import Foundation
import Testing
@testable import CoreKit

@Suite("CoreKit smoke")
struct CoreKitSmokeTests {
    @Test("EntrySnapshot defaults populate now-ish timestamps")
    func entrySnapshotDefaults() {
        let snapshot = EntrySnapshot(content: "hello")
        #expect(snapshot.content == "hello")
        #expect(snapshot.tags.isEmpty)
        #expect(snapshot.mood == nil)
    }

    @Test("EntryQuery.all has no filters")
    func entryQueryAll() {
        let query = EntryQuery.all
        #expect(query.text == nil)
        #expect(query.dateRange == nil)
        #expect(query.moods == nil)
        #expect(query.tags == nil)
    }

    @Test("Mood scale spans 1...5")
    func moodScale() {
        #expect(Mood.allCases.map(\.rawValue) == [1, 2, 3, 4, 5])
    }

    @Test("EntrySnapshot survives JSON round-trip")
    func entrySnapshotCodable() throws {
        let photo = PhotoAssetSnapshot(
            id: UUID(),
            relativePath: "Photos/2026/abc.jpg",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let original = EntrySnapshot(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500),
            content: "a long thought — про себя",
            mood: .good,
            tags: ["morning", "focus"],
            photos: [photo]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EntrySnapshot.self, from: data)
        #expect(decoded == original)
    }

    @Test("InsightSnapshot survives JSON round-trip")
    func insightSnapshotCodable() throws {
        let original = InsightSnapshot(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .weeklyReflection,
            title: "This week",
            body: "You wrote three times and mentioned sleep twice.",
            referencedEntryIDs: [UUID(), UUID()]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InsightSnapshot.self, from: data)
        #expect(decoded == original)
    }

    @Test("SyncEnvelope carries schema version and kind through JSON")
    func syncEnvelopeCodable() throws {
        let payload = EntrySnapshot(content: "x")
        let envelope = SyncEnvelope(kind: .entry, payload: payload)
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(SyncEnvelope<EntrySnapshot>.self, from: data)
        #expect(decoded.schemaVersion == SyncSchemaVersion.current)
        #expect(decoded.kind == .entry)
        #expect(decoded.payload == payload)
    }
}
