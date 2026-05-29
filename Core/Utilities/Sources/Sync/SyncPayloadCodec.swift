import Foundation
import CoreKit

public enum SyncCodecError: Error, LocalizedError, Sendable {
    case unsupportedSchemaVersion(Int)
    case kindMismatch(expected: SyncRecordKind, got: SyncRecordKind)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "Sync payload schema version \(version) is not supported by this build."
        case .kindMismatch(let expected, let got):
            "Sync payload kind mismatch: expected \(expected.rawValue), got \(got.rawValue)."
        }
    }
}

/// Turns domain snapshots into sealed ciphertext ready for CloudKit, and
/// back again. Photo *bytes* are sealed separately via `sealAsset` and
/// ride in a dedicated `CKAsset` field on a companion `PhotoBlob`
/// record; the entry envelope still carries only `PhotoAssetSnapshot`
/// metadata, so an entry re-save doesn't balloon if photos didn't change.
public struct SyncPayloadCodec: Sendable {
    private let encryption: SyncEncryption
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(encryption: SyncEncryption = SyncEncryption()) {
        self.encryption = encryption
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys]
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Entry

    public func encode(_ entry: EntrySnapshot) async throws -> Data {
        try await encode(envelopeFor: .entry, payload: entry)
    }

    public func decodeEntry(_ ciphertext: Data) async throws -> EntrySnapshot {
        try await decode(ciphertext, expecting: .entry)
    }

    // MARK: - Insight

    public func encode(_ insight: InsightSnapshot) async throws -> Data {
        try await encode(envelopeFor: .insight, payload: insight)
    }

    public func decodeInsight(_ ciphertext: Data) async throws -> InsightSnapshot {
        try await decode(ciphertext, expecting: .insight)
    }

    // MARK: - Tombstone

    public func encode(_ tombstone: SyncTombstone) async throws -> Data {
        try await encode(envelopeFor: .deleted, payload: tombstone)
    }

    public func decodeTombstone(_ ciphertext: Data) async throws -> SyncTombstone {
        try await decode(ciphertext, expecting: .deleted)
    }

    // MARK: - Photo blob

    public func encode(_ blob: PhotoBlobSnapshot) async throws -> Data {
        try await encode(envelopeFor: .photo, payload: blob)
    }

    public func decodePhotoBlob(_ ciphertext: Data) async throws -> PhotoBlobSnapshot {
        try await decode(ciphertext, expecting: .photo)
    }

    // MARK: - User sticker blob

    public func encode(_ blob: CustomStickerBlobSnapshot) async throws -> Data {
        try await encode(envelopeFor: .userSticker, payload: blob)
    }

    public func decodeUserStickerBlob(_ ciphertext: Data) async throws -> CustomStickerBlobSnapshot {
        try await decode(ciphertext, expecting: .userSticker)
    }

    /// Seals raw asset bytes (e.g. JPEG data) for the companion `CKAsset`
    /// field. The envelope stays in the record's inline `ciphertext`
    /// field; this sealed buffer rides in the asset file so large photos
    /// don't count against the per-record inline-data soft limit.
    public func sealAsset(_ bytes: Data) async throws -> Data {
        try await encryption.seal(bytes)
    }

    public func openAsset(_ ciphertext: Data) async throws -> Data {
        try await encryption.open(ciphertext)
    }

    // MARK: - Internals

    private func encode<Payload: Codable & Sendable>(
        envelopeFor kind: SyncRecordKind,
        payload: Payload
    ) async throws -> Data {
        let envelope = SyncEnvelope(kind: kind, payload: payload)
        let plaintext = try encoder.encode(envelope)
        return try await encryption.seal(plaintext)
    }

    private func decode<Payload: Codable & Sendable>(
        _ ciphertext: Data,
        expecting: SyncRecordKind
    ) async throws -> Payload {
        let plaintext = try await encryption.open(ciphertext)
        // Two-stage decode: peek at header first so a kind mismatch
        // produces a useful SyncCodecError instead of a random
        // payload-level DecodingError when the wrong generic is used.
        let header = try decoder.decode(EnvelopeHeader.self, from: plaintext)
        guard header.schemaVersion == SyncSchemaVersion.current else {
            throw SyncCodecError.unsupportedSchemaVersion(header.schemaVersion)
        }
        guard header.kind == expecting else {
            throw SyncCodecError.kindMismatch(expected: expecting, got: header.kind)
        }
        return try decoder.decode(SyncEnvelope<Payload>.self, from: plaintext).payload
    }

    private struct EnvelopeHeader: Decodable {
        let schemaVersion: Int
        let kind: SyncRecordKind
    }
}
