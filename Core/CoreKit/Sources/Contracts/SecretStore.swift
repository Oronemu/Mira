import Foundation

/// Abstraction over secret storage (Keychain in production, in-memory in
/// tests). `synchronizable` opts an item into iCloud Keychain sync so it
/// is available on every device signed into the user's Apple ID — used
/// by the sync encryption key.
public protocol SecretStore: Sendable {
    func setString(_ value: String, for account: String, synchronizable: Bool) async throws
    func string(for account: String, synchronizable: Bool) async throws -> String?
    func remove(_ account: String, synchronizable: Bool) async throws
}

extension SecretStore {
    public func setString(_ value: String, for account: String) async throws {
        try await setString(value, for: account, synchronizable: false)
    }

    public func string(for account: String) async throws -> String? {
        try await string(for: account, synchronizable: false)
    }

    public func remove(_ account: String) async throws {
        try await remove(account, synchronizable: false)
    }
}
