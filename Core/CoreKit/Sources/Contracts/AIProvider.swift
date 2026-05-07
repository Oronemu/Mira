import Foundation

/// Single chunk of a streamed model response.
public struct AIResponseChunk: Sendable, Hashable {
    public let textDelta: String
    public let isFinal: Bool

    public init(textDelta: String, isFinal: Bool = false) {
        self.textDelta = textDelta
        self.isFinal = isFinal
    }
}

/// One conversation turn for `AIRequest.messages`.
public struct AIMessage: Sendable, Hashable {
    public enum Role: String, Sendable, Hashable {
        case system, user, assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// Request envelope passed to any `AIProvider`.
public struct AIRequest: Sendable, Hashable {
    public let messages: [AIMessage]
    public let temperature: Double
    public let maxTokens: Int?

    public init(messages: [AIMessage], temperature: Double = 0.7, maxTokens: Int? = nil) {
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

/// Generic AI completion provider. Implemented by `MLXLocalProvider`
/// (on-device, bundled / downloaded model) and `RemoteAIProvider`
/// (Anthropic / OpenAI / OpenRouter).
public protocol AIProvider: Sendable {
    /// Whether the provider can serve requests right now (model loaded,
    /// API key valid, etc).
    var isAvailable: Bool { get async }

    /// `true` when the provider runs a smaller / weaker model and prompt
    /// assembly should switch to high-strictness wording so it resists
    /// in-content instruction injection. Default `false`.
    var requiresStrictPrompts: Bool { get async }

    /// Streams partial responses. Throws `AIError` on failure.
    func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error>
}

public extension AIProvider {
    var requiresStrictPrompts: Bool { get async { false } }
}
