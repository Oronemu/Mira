import Foundation
import Testing
@testable import FeatureEntryList
import CoreKit
import TestSupport

@Suite("EntryListState")
struct EntryListStateTests {
    @MainActor
    @Test("initial observe yields empty list and clears loading")
    func initialEmpty() async throws {
        let repo = MockEntryRepository()
        let state = EntryListState(repository: repo)
        let task = Task { await state.observe() }
        defer { task.cancel() }

        try await wait { !state.isLoading }
        #expect(state.sections.isEmpty)
    }

    @MainActor
    @Test("save in repository broadcasts to state")
    func reactsToSave() async throws {
        let repo = MockEntryRepository()
        let state = EntryListState(repository: repo)
        let task = Task { await state.observe() }
        defer { task.cancel() }

        try await wait { !state.isLoading }
        try await repo.save(EntrySnapshot(content: "first"))

        try await wait { !state.sections.isEmpty }
        #expect(state.sections.first?.entries.first?.content == "first")
    }

    @MainActor
    @Test("delete in repository removes the entry from state")
    func reactsToDelete() async throws {
        let entry = EntrySnapshot(content: "to delete")
        let repo = MockEntryRepository(seed: [entry])
        let state = EntryListState(repository: repo)
        let task = Task { await state.observe() }
        defer { task.cancel() }

        try await wait { !state.sections.isEmpty }
        try await repo.delete(id: entry.id)

        try await wait { state.sections.isEmpty }
    }
}

private struct WaitTimeout: Error {}

@MainActor
private func wait(
    timeout: Duration = .seconds(1),
    _ predicate: @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(15))
    }
    throw WaitTimeout()
}
