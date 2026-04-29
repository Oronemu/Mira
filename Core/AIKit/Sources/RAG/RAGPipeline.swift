import Foundation
import CoreKit

/// Retrieval-augmented generation pipeline. Embeds the user's question,
/// ranks journal entries by cosine similarity, and formats the top hits
/// as a numbered context block that can be spliced into a prompt.
public struct RAGPipeline: Sendable {
    public struct RetrievalResult: Sendable {
        public let snippets: [ScoredEntry]

        public init(snippets: [ScoredEntry] = []) {
            self.snippets = snippets
        }

        public var entries: [EmbeddedEntry] { snippets.map(\.entry) }
    }

    private let embeddingProvider: any EmbeddingProvider
    private let repository: any EntryRepository

    public init(embeddingProvider: any EmbeddingProvider, repository: any EntryRepository) {
        self.embeddingProvider = embeddingProvider
        self.repository = repository
    }

    public func retrieve(query: String, k: Int = 5) async throws -> RetrievalResult {
        guard let queryVector = try await embeddingProvider.embed(query), !queryVector.isEmpty else {
            return RetrievalResult()
        }
        let embedded = try await repository.fetchEmbedded()
        guard !embedded.isEmpty else { return RetrievalResult() }
        let scored = VectorIndex.topK(query: queryVector, against: embedded, k: k)
        return RetrievalResult(snippets: scored)
    }

    public func formatContext(_ result: RetrievalResult, locale: Locale = .autoupdatingCurrent) -> String {
        guard !result.snippets.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return result.snippets.enumerated().map { index, scored in
            let header = "[\(index + 1)] \(formatter.string(from: scored.entry.createdAt))"
            return "\(header)\n\(scored.entry.content)"
        }
        .joined(separator: "\n\n")
    }
}
