import Foundation

/// Curated sticker catalog bundled with the app. Decoupled from persisted
/// entries by `libraryRef` — the user's data stores e.g. `"mira:sun"`
/// and the renderer maps that to a concrete asset at draw time. This lets
/// us rename/replace/extend the bundled pack without breaking existing
/// entries.
///
/// V3 ships full-colour PNG sticker artwork organised into two themed
/// packs: Life and Nature. Entries from earlier versions whose stickers
/// are no longer in the catalog still load fine — the renderer falls
/// back to a placeholder via `StickerImage`.
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
        Pack(id: "life", titleKey: "Life", entries: [
            mira("sneaker"),
            mira("heels"),
            mira("cup"),
            mira("trumpet"),
            mira("glasses"),
            mira("book"),
            mira("gift"),
            mira("globe"),
            mira("sketchbook"),
            mira("pencil"),
            mira("bulb"),
            mira("bubble"),
            mira("plant"),
            mira("tshirt"),
            mira("guitar"),
            mira("palette"),
            mira("mirror"),
            mira("sad_emoji"),
            mira("funny_emoji"),
            mira("picture"),
        ]),
        Pack(id: "nature", titleKey: "Nature", entries: [
            mira("cat"),
            mira("dog"),
            mira("fish"),
            mira("flower"),
            mira("beach"),
            mira("stars"),
            mira("water"),
            mira("clouds"),
            mira("palm_tree"),
            mira("berries"),
            mira("mushrooms"),
            mira("fruits"),
            mira("rain"),
            mira("rainbow"),
            mira("vegetables"),
            mira("moon"),
            mira("butterfly"),
            mira("bug"),
            mira("comet"),
            mira("sun"),
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
