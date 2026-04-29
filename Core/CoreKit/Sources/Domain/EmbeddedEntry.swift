import Foundation

/// Slim view of an entry used for the embedding indexing pipeline. Holds
/// just what the indexer needs to generate a vector. Returned by
/// `EntryRepository.fetchUnindexed`.
public struct UnindexedEntry: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let content: String

    public init(id: UUID, content: String) {
        self.id = id
        self.content = content
    }
}

/// Entry + decoded embedding vector, used by the vector index / RAG.
public struct EmbeddedEntry: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let content: String
    public let embedding: [Float]

    public init(id: UUID, createdAt: Date, content: String, embedding: [Float]) {
        self.id = id
        self.createdAt = createdAt
        self.content = content
        self.embedding = embedding
    }
}
