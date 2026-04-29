import Foundation
import CryptoKit
import CoreKit

public enum SyncEncryptionError: Error, LocalizedError, Sendable {
    case keyGenerationFailed
    case sealFailed
    case openFailed

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: "Could not generate the sync encryption key."
        case .sealFailed: "Could not encrypt the sync payload."
        case .openFailed: "Could not decrypt the sync payload."
        }
    }
}

/// ChaChaPoly-backed envelope for sync payloads. The symmetric key is
/// stored in iCloud Keychain (`kSecAttrSynchronizable`) so every device
/// signed into the user's Apple ID can decrypt records pulled from
/// CloudKit. Apple keeps the iCloud Keychain itself end-to-end encrypted,
/// so the raw key never reaches Apple's servers in plaintext. CloudKit
/// only ever sees the ciphertext.
public struct SyncEncryption: Sendable {
    public static let keyAccount = "sync.symmetric-key.v1"

    private let store: any SecretStore

    public init(store: any SecretStore = KeychainStore()) {
        self.store = store
    }

    public func seal(_ plaintext: Data) async throws -> Data {
        let key = try await ensureKey()
        do {
            let box = try ChaChaPoly.seal(plaintext, using: key)
            return box.combined
        } catch {
            throw SyncEncryptionError.sealFailed
        }
    }

    public func open(_ ciphertext: Data) async throws -> Data {
        let key = try await ensureKey()
        do {
            let box = try ChaChaPoly.SealedBox(combined: ciphertext)
            return try ChaChaPoly.open(box, using: key)
        } catch {
            throw SyncEncryptionError.openFailed
        }
    }

    /// Drops the saved key — used when the user disables sync so a
    /// re-enable starts from a fresh key. Removes both the synced slot
    /// and any legacy device-only copy left by older builds.
    public func rotateKey() async throws {
        try await store.remove(Self.keyAccount, synchronizable: true)
        try await store.remove(Self.keyAccount)
    }

    private func ensureKey() async throws -> SymmetricKey {
        if let encoded = try await store.string(for: Self.keyAccount, synchronizable: true),
           let data = Data(base64Encoded: encoded) {
            return SymmetricKey(data: data)
        }
        // Migrate a legacy device-only key from older builds into the
        // synced slot. Keeps existing users from losing decryption
        // capability the first time they launch a build with sync.
        if let encoded = try await store.string(for: Self.keyAccount),
           let data = Data(base64Encoded: encoded) {
            try await store.setString(encoded, for: Self.keyAccount, synchronizable: true)
            try await store.remove(Self.keyAccount)
            return SymmetricKey(data: data)
        }
        let newKey = SymmetricKey(size: .bits256)
        let encoded = newKey.withUnsafeBytes { Data($0) }.base64EncodedString()
        try await store.setString(encoded, for: Self.keyAccount, synchronizable: true)
        return newKey
    }
}
