import Foundation

public struct UnimplementedAIProvider: AIProvider {
    public init() {}

    public var isAvailable: Bool {
        get async { false }
    }

    public func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        assertionFailure("UnimplementedAIProvider.stream called — wire a real AIProvider in ServiceContainer.")
        throw AIError.noProviderConfigured
    }
}
