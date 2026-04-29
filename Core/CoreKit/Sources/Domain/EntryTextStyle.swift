import Foundation
import CoreGraphics

/// Aggregate of formatting attributes applied to an entry's body text.
///
/// Stored per-entry; edited via the dock's "Aa" control in both creation and
/// editing flows. All fields are domain-level — rendering/typography lives
/// in `DesignSystem`.
public struct EntryTextStyle: Sendable, Hashable, Codable {
    public var size: EntryFontSize
    public var family: EntryFontFamily
    public var color: EntryTextColor

    public init(
        size: EntryFontSize = .regular,
        family: EntryFontFamily = .serif,
        color: EntryTextColor = .preset(.default)
    ) {
        self.size = size
        self.family = family
        self.color = color
    }

    public static let `default` = EntryTextStyle()
}

/// Discrete body font sizes offered to the user.
public enum EntryFontSize: Int, Sendable, Hashable, Codable, CaseIterable {
    case small = 0
    case regular = 1
    case large = 2
    case extraLarge = 3

    public var pointSize: CGFloat {
        switch self {
        case .small: 15
        case .regular: 17
        case .large: 19
        case .extraLarge: 22
        }
    }

    public var label: String {
        switch self {
        case .small: "Small"
        case .regular: "Regular"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }
}

/// Curated font families. Resolved to a concrete SwiftUI `Font` in
/// `DesignSystem.MiraTypography`.
public enum EntryFontFamily: String, Sendable, Hashable, Codable, CaseIterable {
    case serif       // New York (editorial default)
    case sans        // SF Pro
    case rounded     // SF Pro Rounded
    case monospaced  // SF Mono (typewriter)
    case georgia     // Georgia (warm classic serif)
    case avenirNext  // Avenir Next (humanist sans)

    public var label: String {
        switch self {
        case .serif: "Serif"
        case .sans: "Sans"
        case .rounded: "Rounded"
        case .monospaced: "Typewriter"
        case .georgia: "Georgia"
        case .avenirNext: "Avenir"
        }
    }
}

/// Either a curated preset (adapts to light/dark mode via the palette) or a
/// user-chosen custom colour stored as a hex string. Persistence serialises
/// this as a single string ("preset:<name>" or "hex:#RRGGBB").
public enum EntryTextColor: Sendable, Hashable, Codable {
    case preset(Preset)
    case custom(hex: String)

    public enum Preset: String, Sendable, Hashable, Codable, CaseIterable {
        case `default`
        case muted
        case warm
        case cool
        case rose
        case forest
        case plum
        case rust

        public var label: String {
            switch self {
            case .default: "Default"
            case .muted: "Muted"
            case .warm: "Warm"
            case .cool: "Cool"
            case .rose: "Rose"
            case .forest: "Forest"
            case .plum: "Plum"
            case .rust: "Rust"
            }
        }
    }
}

public extension EntryTextColor {
    /// Serialised form used by persistence: `"preset:<name>"` or `"hex:#RRGGBB"`.
    var storageString: String {
        switch self {
        case .preset(let preset): "preset:\(preset.rawValue)"
        case .custom(let hex): "hex:\(hex)"
        }
    }

    init?(storageString: String) {
        if let rest = storageString.dropPrefix("preset:"),
           let preset = Preset(rawValue: String(rest)) {
            self = .preset(preset)
            return
        }
        if let rest = storageString.dropPrefix("hex:") {
            self = .custom(hex: String(rest))
            return
        }
        return nil
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> Substring? {
        guard hasPrefix(prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
