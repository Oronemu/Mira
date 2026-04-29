import Foundation
import NaturalLanguage
import CoreKit

/// On-device embedding backed by Apple's NaturalLanguage sentence model.
/// Returns nil for languages without a shipped model; callers should treat
/// that as "unable to index" rather than as an error.
public struct NLEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    private let embedding: NLEmbedding
    public let dimensions: Int

    public init?(language: NLLanguage = .english) {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else {
            return nil
        }
        self.embedding = embedding
        self.dimensions = embedding.dimension
    }

    public func embed(_ text: String) async throws -> [Float]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let vector = embedding.vector(for: trimmed) else { return nil }
        return vector.map { Float($0) }
    }
}
