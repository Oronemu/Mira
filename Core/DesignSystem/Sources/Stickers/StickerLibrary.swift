import Foundation

/// Curated sticker catalog bundled with the app. Decoupled from persisted
/// entries by `libraryRef` — the user's data stores e.g. `"mira:sun"`
/// and the renderer maps that to a concrete asset at draw time. This lets
/// us rename/replace/extend the bundled pack without breaking existing
/// entries.
///
/// V2 ships full-colour PNG sticker artwork (Flaticon Free, attribution
/// required — see `Resources/FLATICON_ATTRIBUTION.txt`) organised into
/// five themed packs.
public enum StickerLibrary {
    /// Stable category id used in UI segmenting. Title is localised at
    /// access time via `String(localized:)`.
    public struct Pack: Sendable, Identifiable {
        public let id: String
        public let titleKey: LocalizedStringResource
        public let entries: [Entry]

        public init(id: String, titleKey: LocalizedStringResource, entries: [Entry]) {
            self.id = id
            self.titleKey = titleKey
            self.entries = entries
        }

        public var title: String { String(localized: titleKey) }
    }

    public struct Entry: Sendable, Hashable, Identifiable {
        /// Stable, persisted reference. e.g. `"mira:sun"`. Never rename
        /// once shipped — old entries depend on the literal string.
        public let id: String
        /// Image name inside `Stickers.xcassets`.
        public let assetName: String

        public init(id: String, assetName: String) {
            self.id = id
            self.assetName = assetName
        }
    }

    // MARK: - Catalog

    public static let packs: [Pack] = [
        Pack(id: "kawaii", titleKey: "Cute", entries: [
            mira("sun"),
            mira("cloud_bright"),
            mira("crown"),
            mira("pencil"),
            mira("watermelon"),
            mira("gold_star"),
            mira("sparks"),
            mira("windy"),
            mira("smile_cat"),
            mira("rice_cat"),
        ]),
        Pack(id: "sleepy", titleKey: "Sleepy", entries: [
            mira("cloud_sleepy"),
            mira("moon"),
        ]),
        Pack(id: "sparkle", titleKey: "Love", entries: [
            mira("heart_pink"),
            mira("book_glitter"),
            mira("love"),
        ]),
        Pack(id: "path", titleKey: "Adventures", entries: [
            mira("mountain"),
            mira("forest"),
            mira("road_sign"),
            mira("compass"),
            mira("target"),
            mira("notebooks"),
            mira("lightbulb"),
        ]),
        Pack(id: "sketches", titleKey: "Sketches", entries: [
            mira("pigeon"),
            mira("wine"),
            mira("flower"),
            mira("leaf"),
            mira("heart_lace"),
        ]),
    ]

    /// Flat lookup — used by the renderer when it has only a `libraryRef`.
    public static func entry(for ref: String) -> Entry? {
        index[ref]
    }

    private static let index: [String: Entry] = {
        var map: [String: Entry] = [:]
        for pack in packs {
            for entry in pack.entries {
                map[entry.id] = entry
            }
        }
        return map
    }()

    public static var totalCount: Int {
        packs.reduce(0) { $0 + $1.entries.count }
    }

    // MARK: - Helpers

    private static func mira(_ name: String) -> Entry {
        Entry(id: "mira:\(name)", assetName: "sticker_\(name)")
    }
}
