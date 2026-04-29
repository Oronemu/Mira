import Foundation

public struct UnimplementedEmbeddingProvider: EmbeddingProvider {
    public init() {}

    public var dimensions: Int { 0 }

    public func embed(_ text: String) async throws -> [Float]? {
        assertionFailure("UnimplementedEmbeddingProvider.embed called — wire a real EmbeddingProvider in ServiceContainer.")
        return nil
    }
}
