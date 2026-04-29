import Foundation

/// Immutable, Sendable view of an entry that crosses module boundaries.
/// `Persistence` translates `@Model Entry` into this; UI/state-containers
/// only ever see this type — never SwiftData.
///
/// Content is stored as `AttributedString` so per-selection formatting
/// (font family, size, colour, bold/italic/underline) is preserved. Callers
/// that only need the plain-text body (search, embedding indexing, sync
/// payloads) should read `plainContent` instead of walking `content.characters`.
public struct EntrySnapshot: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let updatedAt: Date
    public let content: AttributedString
    public let mood: Mood?
    public let tags: [String]
    public let photos: [PhotoAssetSnapshot]
    public let stickers: [EntryStickerInstance]

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        content: AttributedString,
        mood: Mood? = nil,
        tags: [String] = [],
        photos: [PhotoAssetSnapshot] = [],
        stickers: [EntryStickerInstance] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.content = content
        self.mood = mood
        self.tags = tags
        self.photos = photos
        self.stickers = stickers
    }

    /// Convenience for constructing a snapshot from plain text (e.g. from
    /// tests, migrations, or call sites that haven't been touched up yet).
    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        plainContent: String,
        mood: Mood? = nil,
        tags: [String] = [],
        photos: [PhotoAssetSnapshot] = [],
        stickers: [EntryStickerInstance] = []
    ) {
        self.init(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            content: AttributedString(plainContent),
            mood: mood,
            tags: tags,
            photos: photos,
            stickers: stickers
        )
    }

    /// Plain-text view of the body. Used by search, embedding indexing, sync,
    /// and anything that doesn't care about formatting.
    public var plainContent: String {
        String(content.characters)
    }
}

// MARK: - Codable

extension EntrySnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, contentData, mood, tags, photos, stickers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        let data = try container.decode(Data.self, forKey: .contentData)
        self.content = try EntryContentCodec.decode(data)
        self.mood = try container.decodeIfPresent(Mood.self, forKey: .mood)
        self.tags = try container.decode([String].self, forKey: .tags)
        self.photos = try container.decode([PhotoAssetSnapshot].self, forKey: .photos)
        self.stickers = try container.decodeIfPresent([EntryStickerInstance].self, forKey: .stickers) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(EntryContentCodec.encode(content), forKey: .contentData)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encode(tags, forKey: .tags)
        try container.encode(photos, forKey: .photos)
        if !stickers.isEmpty {
            try container.encode(stickers, forKey: .stickers)
        }
    }
}
