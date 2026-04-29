import Foundation

/// User-facing AI configuration. Persisted in `UserDefaults`; API keys
/// live in `KeychainStore`. `.local` uses MLXLocalProvider against a
/// downloaded on-device model; `.remote` talks to Anthropic / OpenAI /
/// OpenRouter with the user's key.
public struct AISettings: Sendable, Hashable, Codable {
    public enum ProviderKind: String, Sendable, Hashable, Codable {
        case off
        case local
        case remote
    }

    public var provider: ProviderKind
    public var remote: RemoteConfig

    public init(provider: ProviderKind = .local, remote: RemoteConfig = .default) {
        self.provider = provider
        self.remote = remote
    }

    public var isEnabled: Bool { provider != .off }
}

public extension AISettings {
    static let `default` = AISettings()
}

/// Thin wrapper around `UserDefaults` for persisting `AISettings`.
/// Uses the app-group suite so widgets can read the same preference.
public struct AISettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "ai.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AISettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AISettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: AISettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
