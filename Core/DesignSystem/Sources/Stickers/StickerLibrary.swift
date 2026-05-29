import Foundation

/// Curated sticker catalog bundled with the app. Decoupled from persisted
/// entries by `libraryRef` — the user's data stores e.g. `"mira:sun"`
/// and the renderer maps that to a concrete asset at draw time. This lets
/// us rename/replace/extend the bundled pack without breaking existing
/// entries.
///
/// The picker exposes `pickerEntries` — the current drawstyle pack.
/// Earlier themed packs (`packs`) are still resolvable via `entry(for:)`
/// so entries placed before the redesign keep rendering correctly.
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

    /// The current bundled sticker set. This is what the picker shows.
    /// New entries placed by the user reference these.
    public static let pickerEntries: [Entry] = [
        drawstyle("arrow-sign"),
        drawstyle("battery-high"),
        drawstyle("battery-low"),
        drawstyle("brain"),
        drawstyle("camera"),
        drawstyle("capybara"),
        drawstyle("cat"),
        drawstyle("compass"),
        drawstyle("diary"),
        drawstyle("dog"),
        drawstyle("feather"),
        drawstyle("flower"),
        drawstyle("giftbox"),
        drawstyle("guitar"),
        drawstyle("headphones"),
        drawstyle("heart-damaged"),
        drawstyle("heart"),
        drawstyle("lightbulb"),
        drawstyle("map"),
        drawstyle("moon"),
        drawstyle("mountain"),
        drawstyle("notebook"),
        drawstyle("rain-cloud"),
        drawstyle("sun"),
    ]

    /// Legacy themed packs shipped before the drawstyle redesign. Kept in
    /// the catalog so entries placed against `"mira:sun"`, `"mira:cat"`,
    /// etc. continue to resolve. Not shown in the picker.
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
    /// Resolves both current (drawstyle) and legacy refs.
    public static func entry(for ref: String) -> Entry? {
        index[ref]
    }

    private static let index: [String: Entry] = {
        var map: [String: Entry] = [:]
        for entry in pickerEntries {
            map[entry.id] = entry
        }
        for pack in packs {
            for entry in pack.entries {
                // Don't overwrite drawstyle entries if a legacy ref collides —
                // current pack wins by being inserted first.
                if map[entry.id] == nil {
                    map[entry.id] = entry
                }
            }
        }
        return map
    }()

    public static var totalCount: Int {
        pickerEntries.count + packs.reduce(0) { $0 + $1.entries.count }
    }

    // MARK: - Helpers

    private static func mira(_ name: String) -> Entry {
        Entry(id: "mira:\(name)", assetName: "sticker_\(name)")
    }

    private static func drawstyle(_ name: String) -> Entry {
        Entry(id: "mira:drawstyle-\(name)", assetName: "drawstyle-\(name)")
    }
}
