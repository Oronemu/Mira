import Foundation

/// Produces dense vector representations of text for semantic search / RAG.
public protocol EmbeddingProvider: Sendable {
    /// Dimensionality of vectors this provider returns.
    var dimensions: Int { get }

    /// Returns an embedding for a single string, or nil if the provider
    /// cannot embed it (e.g. unsupported language).
    func embed(_ text: String) async throws -> [Float]?
}
