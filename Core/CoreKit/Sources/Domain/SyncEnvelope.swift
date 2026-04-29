import Foundation

/// Versioned wrapper around an encoded domain payload. The envelope is
/// serialized to JSON, sealed with `SyncEncryption`, then pushed to
/// CloudKit as an opaque `Data` blob. `schemaVersion` lets readers
/// detect payloads written by newer builds and decide whether to
/// migrate, ignore, or surface an upgrade prompt.
public struct SyncEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let schemaVersion: Int
    public let kind: SyncRecordKind
    public let payload: Payload

    public init(schemaVersion: Int = SyncSchemaVersion.current, kind: SyncRecordKind, payload: Payload) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.payload = payload
    }
}

public enum SyncSchemaVersion {
    public static let current = 1
}
