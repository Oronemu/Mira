import Foundation
import SwiftData

@Model
public final class Entry {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    /// Plain-text shadow of the body. Always kept in sync with `contentData`
    /// on write — used directly by search, embedding indexing, and sync so
    /// callers don't pay for AttributedString decoding.
    public var content: String
    public var mood: Int?
    public var tags: [String]
    public var embedding: Data?

    /// Serialised `AttributedString` body (via `EntryContentCodec`). Nil for
    /// entries predating the rich-text rollout; those are hydrated at read
    /// time from `content` + the legacy style fields below.
    public var contentData: Data?

    /// Serialised sticker collection (via `EntryStickersCodec`). Nil for
    /// entries that have never had stickers — equivalent to an empty array.
    public var stickersData: Data?

    /// Legacy per-entry style fields. Still read by `Entry+Snapshot` for
    /// records that lack `contentData`. Not written to by the new save
    /// path — `contentData` carries range-level attributes instead.
    public var fontSizeLevel: Int = 1
    public var fontFamilyRaw: String = "serif"
    public var textColorSpec: String = "preset:default"

    @Relationship(deleteRule: .cascade, inverse: \PhotoAsset.entry)
    public var photos: [PhotoAsset]

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        content: String,
        mood: Int? = nil,
        tags: [String] = [],
        embedding: Data? = nil,
        contentData: Data? = nil,
        stickersData: Data? = nil,
        fontSizeLevel: Int = 1,
        fontFamilyRaw: String = "serif",
        textColorSpec: String = "preset:default"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.content = content
        self.mood = mood
        self.tags = tags
        self.embedding = embedding
        self.contentData = contentData
        self.stickersData = stickersData
        self.fontSizeLevel = fontSizeLevel
        self.fontFamilyRaw = fontFamilyRaw
        self.textColorSpec = textColorSpec
        self.photos = []
    }
}
