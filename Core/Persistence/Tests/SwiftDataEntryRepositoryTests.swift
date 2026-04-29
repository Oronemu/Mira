import Foundation
import SwiftData
import Testing
@testable import Persistence
import CoreKit

@MainActor
private func makeRepository() throws -> SwiftDataEntryRepository {
    let container = try ModelContainerFactory.inMemory()
    return SwiftDataEntryRepository(modelContainer: container)
}

@Suite("SwiftDataEntryRepository")
struct SwiftDataEntryRepositoryTests {
    @Test("save and fetch round-trip preserves fields")
    func saveFetchRoundTrip() async throws {
        let repo = try await makeRepository()
        let snapshot = EntrySnapshot(
            content: "Coffee, sun, code.",
            mood: .good,
            tags: ["morning", "focus"]
        )

        try await repo.save(snapshot)
        let fetched = try await repo.fetch(id: snapshot.id)

        #expect(fetched?.content == "Coffee, sun, code.")
        #expect(fetched?.mood == .good)
        #expect(Set(fetched?.tags ?? []) == ["morning", "focus"])
    }

    @Test("save updates existing entry instead of duplicating")
    func updateExisting() async throws {
        let repo = try await makeRepository()
        let original = EntrySnapshot(content: "first", mood: .neutral)
        try await repo.save(original)

        let edited = EntrySnapshot(
            id: original.id,
            createdAt: original.createdAt,
            updatedAt: .now,
            content: "second",
            mood: .veryGood,
            tags: ["edited"]
        )
        try await repo.save(edited)

        let all = try await repo.fetch(matching: .all)
        #expect(all.count == 1)
        #expect(all.first?.content == "second")
        #expect(all.first?.mood == .veryGood)
        #expect(all.first?.tags == ["edited"])
    }

    @Test("delete removes the entry")
    func deleteRemoves() async throws {
        let repo = try await makeRepository()
        let entry = EntrySnapshot(content: "to delete")
        try await repo.save(entry)

        try await repo.delete(id: entry.id)

        #expect(try await repo.fetch(id: entry.id) == nil)
        #expect(try await repo.fetch(matching: .all).isEmpty)
    }

    @Test("text query filters by case-insensitive substring")
    func textQuery() async throws {
        let repo = try await makeRepository()
        try await repo.save(EntrySnapshot(content: "Quiet morning"))
        try await repo.save(EntrySnapshot(content: "Loud afternoon"))

        var query = EntryQuery.all
        query.text = "MORNING"
        let result = try await repo.fetch(matching: query)
        #expect(result.count == 1)
        #expect(result.first?.content == "Quiet morning")
    }

    @Test("mood filter narrows results")
    func moodQuery() async throws {
        let repo = try await makeRepository()
        try await repo.save(EntrySnapshot(content: "calm", mood: .neutral))
        try await repo.save(EntrySnapshot(content: "happy", mood: .veryGood))

        var query = EntryQuery.all
        query.moods = [.veryGood]
        let result = try await repo.fetch(matching: query)
        #expect(result.map(\.content) == ["happy"])
    }

    @Test("observe yields current snapshot then again on save")
    func observeBroadcastsOnSave() async throws {
        let repo = try await makeRepository()
        let stream = repo.observe(query: .all)

        var iterator = stream.makeAsyncIterator()
        let initial = await iterator.next()
        #expect(initial?.isEmpty == true)

        try await repo.save(EntrySnapshot(content: "hello"))
        let next = await iterator.next()
        #expect(next?.count == 1)
        #expect(next?.first?.content == "hello")
    }

    @Test("photos round-trip through reconcile")
    func photoRoundTrip() async throws {
        let repo = try await makeRepository()
        let photo = PhotoAssetSnapshot(relativePath: "Photos/abc.jpg")
        let entry = EntrySnapshot(content: "with photo", photos: [photo])

        try await repo.save(entry)
        let fetched = try await repo.fetch(id: entry.id)
        #expect(fetched?.photos.count == 1)
        #expect(fetched?.photos.first?.relativePath == "Photos/abc.jpg")
    }

    @Test("changes stream emits upserted on save and deleted on delete")
    func changesStreamEmitsEvents() async throws {
        let repo = try await makeRepository()
        let stream = repo.changes()
        var iterator = stream.makeAsyncIterator()

        let entry = EntrySnapshot(content: "emit me")
        try await repo.save(entry)
        let first = await iterator.next()
        #expect(first == .upserted(entry))

        try await repo.delete(id: entry.id)
        let second = await iterator.next()
        #expect(second == .deleted(entry.id))
    }
}
