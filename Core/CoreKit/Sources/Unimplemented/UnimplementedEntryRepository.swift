import Foundation

/// Default `EntryRepository` wired into `EnvironmentValues`. Asserts on every
/// call so missing real injection in App is caught loudly during development.
public struct UnimplementedEntryRepository: EntryRepository {
    public init() {}

    public func fetch(matching query: EntryQuery) async throws -> [EntrySnapshot] {
        unimplemented(#function)
    }

    public func fetch(id: UUID) async throws -> EntrySnapshot? {
        unimplemented(#function)
    }

    public func save(_ entry: EntrySnapshot) async throws {
        unimplemented(#function)
    }

    public func delete(id: UUID) async throws {
        unimplemented(#function)
    }

    public func observe(query: EntryQuery) -> AsyncStream<[EntrySnapshot]> {
        unimplemented(#function)
    }

    public func changes() -> AsyncStream<EntryChange> {
        unimplemented(#function)
    }

    public func fetchUnindexed(limit: Int) async throws -> [UnindexedEntry] {
        unimplemented(#function)
    }

    public func updateEmbedding(id: UUID, data: Data?) async throws {
        unimplemented(#function)
    }

    public func fetchEmbedded() async throws -> [EmbeddedEntry] {
        unimplemented(#function)
    }

    public func recentTags(limit: Int) async throws -> [String] {
        unimplemented(#function)
    }

    private func unimplemented(_ method: String) -> Never {
        assertionFailure("UnimplementedEntryRepository.\(method) called — wire a real EntryRepository in ServiceContainer.")
        fatalError("UnimplementedEntryRepository.\(method)")
    }
}
