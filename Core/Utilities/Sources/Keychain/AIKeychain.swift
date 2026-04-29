import Foundation

/// Thin facade over `KeychainStore` for per-provider API keys. The account
/// names are stable so switching providers preserves previously saved keys.
public struct AIKeychain: Sendable {
    private let store: KeychainStore

    public init(store: KeychainStore = KeychainStore()) {
        self.store = store
    }

    public func apiKey(for provider: RemoteConfig.Provider) async throws -> String? {
        try await store.string(for: Self.account(for: provider))
    }

    public func setAPIKey(_ key: String, for provider: RemoteConfig.Provider) async throws {
        try await store.setString(key, for: Self.account(for: provider))
    }

    public func removeAPIKey(for provider: RemoteConfig.Provider) async throws {
        try await store.remove(Self.account(for: provider))
    }

    private static func account(for provider: RemoteConfig.Provider) -> String {
        "ai.apikey.\(provider.rawValue)"
    }
}
