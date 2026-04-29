import Foundation

/// User-configurable remote AI endpoint. Persisted alongside `AISettings`
/// in `UserDefaults`; the API key lives in `AIKeychain` so it stays out of
/// backups and never crosses module boundaries unless explicitly fetched.
public struct RemoteConfig: Sendable, Hashable, Codable {
    public enum Provider: String, Sendable, Hashable, Codable, CaseIterable {
        case anthropic
        case openai
        case openrouter

        public var displayName: String {
            switch self {
            case .anthropic: "Anthropic"
            case .openai: "OpenAI"
            case .openrouter: "OpenRouter"
            }
        }

        /// Sensible default model for each provider. The user can override
        /// via Settings; this is just what we ship out of the box.
        public var defaultModel: String {
            switch self {
            case .anthropic: "claude-sonnet-4-6"
            case .openai: "gpt-4o-mini"
            case .openrouter: "anthropic/claude-sonnet-4-6"
            }
        }
    }

    public var provider: Provider
    public var model: String

    public init(provider: Provider = .anthropic, model: String? = nil) {
        self.provider = provider
        self.model = model ?? provider.defaultModel
    }
}

public extension RemoteConfig {
    static let `default` = RemoteConfig()
}
