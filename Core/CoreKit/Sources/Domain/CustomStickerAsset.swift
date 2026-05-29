import Foundation

/// User-created sticker persisted on disk. Mirrors `PhotoAssetSnapshot`
/// in shape — bytes never live in SwiftData, the store keeps only the
/// relative path the renderer can resolve back to PNG data.
///
/// The `libraryRef` shape (`"user:<uuid>"`) is the contract between
/// `CustomStickerStoring` and `StickerImage`: the renderer branches on
/// the `"user:"` prefix and pulls bytes through the environment store
/// instead of `StickerLibrary`. Stable forever — `EntryStickerInstance`
/// values persist this string and old refs must keep resolving.
public struct CustomStickerAsset: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    /// Disk-relative path (e.g. `"Stickers/<uuid>.png"`). Resolved by the
    /// store rather than embedded as a libraryRef so we can rearrange the
    /// directory layout without rewriting persisted entries.
    public let relativePath: String
    public let createdAt: Date

    public init(id: UUID, relativePath: String, createdAt: Date) {
        self.id = id
        self.relativePath = relativePath
        self.createdAt = createdAt
    }

    /// Stable reference embedded in `EntryStickerInstance.libraryRef`.
    /// `StickerImage` branches on this prefix to route resolution.
    public var libraryRef: String { Self.libraryRef(for: id) }

    public static func libraryRef(for id: UUID) -> String {
        "user:\(id.uuidString)"
    }

    /// Parses a `"user:<uuid>"` ref back to its UUID. Returns `nil` for
    /// any other format (e.g. `"mira:sun"`) so the renderer can fall
    /// through to the bundled library cleanly.
    public static func id(fromLibraryRef ref: String) -> UUID? {
        guard ref.hasPrefix("user:") else { return nil }
        return UUID(uuidString: String(ref.dropFirst("user:".count)))
    }
}
