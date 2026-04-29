import Foundation
import CoreKit

/// In-memory `SecretStore` backed by a dictionary keyed on (account,
/// synchronizable) so tests exercise the sync-vs-local split without
/// touching the real Keychain (which requires entitlements unavailable
/// to unit-test bundles).
public actor InMemorySecretStore: SecretStore {
    private struct Key: Hashable {
        let account: String
        let synchronizable: Bool
    }

    private var storage: [Key: String] = [:]

    public init() {}

    public func setString(_ value: String, for account: String, synchronizable: Bool) async throws {
        storage[Key(account: account, synchronizable: synchronizable)] = value
    }

    public func string(for account: String, synchronizable: Bool) async throws -> String? {
        storage[Key(account: account, synchronizable: synchronizable)]
    }

    public func remove(_ account: String, synchronizable: Bool) async throws {
        storage.removeValue(forKey: Key(account: account, synchronizable: synchronizable))
    }
}
