import Foundation
import CoreKit

/// Silent no-op provider. Reports unavailable and fails any stream attempt
/// with `.noProviderConfigured`. Used as the default when the user has AI
/// turned off in Settings. Unlike `UnimplementedAIProvider` it does not
/// assert — it is a valid runtime state.
public struct NoAIProvider: AIProvider {
    public init() {}

    public var isAvailable: Bool {
        get async { false }
    }

    public func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        throw AIError.noProviderConfigured
    }
}
