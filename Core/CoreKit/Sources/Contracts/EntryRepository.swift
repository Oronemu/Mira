import Foundation

/// Persistence boundary for journal entries. Implemented by Persistence
/// module (`SwiftDataEntryRepository`); never references SwiftData here.
public protocol EntryRepository: Sendable {
    func fetch(matching query: EntryQuery) async throws -> [EntrySnapshot]
    func fetch(id: UUID) async throws -> EntrySnapshot?
    func save(_ entry: EntrySnapshot) async throws
    func delete(id: UUID) async throws

    /// Reactive stream of entries that match `query`. Emits the current
    /// snapshot immediately, then again on every relevant change.
    func observe(query: EntryQuery) -> AsyncStream<[EntrySnapshot]>

    /// Per-row change stream consumed by the CloudKit pusher. Yields a
    /// `.upserted` event for every save and a `.deleted` event for every
    /// delete, in the order writes land. Does not replay history — new
    /// subscribers only see events from their subscription forward.
    func changes() -> AsyncStream<EntryChange>

    // MARK: - Embedding indexing

    /// Returns entries whose embedding column is still `nil`. Used by the
    /// indexer; empty `Data` marks "tried, no vector" and is not returned
    /// so we don't loop on languages without a shipped model.
    func fetchUnindexed(limit: Int) async throws -> [UnindexedEntry]

    /// Persists (or clears) the embedding blob for an entry. Pass `Data()`
    /// to signal "no vector available" without nil-ing the column.
    func updateEmbedding(id: UUID, data: Data?) async throws

    /// Returns every entry that has a decodable embedding vector, for the
    /// in-memory vector index / RAG pipeline.
    func fetchEmbedded() async throws -> [EmbeddedEntry]

    // MARK: - Tags

    /// Distinct tags from the most recent entries, ordered by most-recent
    /// first use. Powers the tag-picker's "recent tags" affordance.
    func recentTags(limit: Int) async throws -> [String]
}
