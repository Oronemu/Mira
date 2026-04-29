import Foundation
import Security
import CoreKit

public enum KeychainError: LocalizedError, Sendable {
    case unhandled(OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            "Keychain error: \(status)"
        case .invalidData:
            "Keychain returned data that could not be decoded as UTF-8."
        }
    }
}

/// Thin actor wrapping the Security framework.
///
/// Items default to `WhenUnlockedThisDeviceOnly` accessibility and are NOT
/// synced to iCloud Keychain. Pass `synchronizable: true` to opt an
/// individual item into iCloud Keychain sync — used by `SyncEncryption`
/// so the end-to-end sync key is available on every device signed into
/// the user's Apple ID. Syncable items drop the ThisDeviceOnly attribute
/// (Apple forbids combining them).
public actor KeychainStore: SecretStore {
    private let service: String

    public init(service: String = "com.veilbytesoft.Mira") {
        self.service = service
    }

    public func setString(_ value: String, for account: String, synchronizable: Bool) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.invalidData }
        try set(data, for: account, synchronizable: synchronizable)
    }

    public func string(for account: String, synchronizable: Bool) throws -> String? {
        guard let data = try data(for: account, synchronizable: synchronizable) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else { throw KeychainError.invalidData }
        return string
    }

    public func remove(_ account: String, synchronizable: Bool) throws {
        let query = baseQuery(account: account, synchronizable: synchronizable)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    private func set(_ data: Data, for account: String, synchronizable: Bool) throws {
        let query = baseQuery(account: account, synchronizable: synchronizable)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = synchronizable
            ? kSecAttrAccessibleWhenUnlocked
            : kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    private func data(for account: String, synchronizable: Bool) throws -> Data? {
        var query = baseQuery(account: account, synchronizable: synchronizable)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status)
        }
    }

    private func baseQuery(account: String, synchronizable: Bool) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: synchronizable ? kCFBooleanTrue! : kCFBooleanFalse!,
        ]
    }
}
