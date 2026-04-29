import Foundation
import SwiftData
import Testing
@testable import Persistence
import CoreKit

@MainActor
private func makeRepository() throws -> SwiftDataInsightRepository {
    let container = try ModelContainerFactory.inMemory()
    return SwiftDataInsightRepository(modelContainer: container)
}

@Suite("SwiftDataInsightRepository")
struct SwiftDataInsightRepositoryTests {
    @Test("save then fetchAll returns the insight")
    func saveFetchAll() async throws {
        let repo = try await makeRepository()
        let insight = InsightSnapshot(
            kind: .weeklyReflection,
            title: "Week 14",
            body: "You wrote on 5 of 7 days."
        )

        try await repo.save(insight)
        let all = try await repo.fetchAll()

        #expect(all.count == 1)
        #expect(all.first?.title == "Week 14")
    }

    @Test("delete removes the insight")
    func delete() async throws {
        let repo = try await makeRepository()
        let insight = InsightSnapshot(
            kind: .askMiraAnswer,
            title: "q",
            body: "a"
        )
        try await repo.save(insight)

        try await repo.delete(id: insight.id)
        #expect(try await repo.fetchAll().isEmpty)
    }

    @Test("changes stream emits upserted on save and deleted on delete")
    func changesStreamEmitsEvents() async throws {
        let repo = try await makeRepository()
        let stream = repo.changes()
        var iterator = stream.makeAsyncIterator()

        let insight = InsightSnapshot(kind: .weeklyReflection, title: "t", body: "b")
        try await repo.save(insight)
        let first = await iterator.next()
        #expect(first == .upserted(insight))

        try await repo.delete(id: insight.id)
        let second = await iterator.next()
        #expect(second == .deleted(insight.id))
    }
}
