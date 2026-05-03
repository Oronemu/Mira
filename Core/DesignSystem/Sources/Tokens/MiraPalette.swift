import SwiftUI
import UIKit
import CoreKit
import Utilities

/// Semantic colour palette. Named `Palette` (not `Colors`) to avoid colliding
/// with Tuist's auto-generated `MiraColors` asset namespace in the App target.
public enum MiraPalette {
    // MARK: - System

    public static let accent = Color.accentColor
    public static let background = Color(UIColor.systemBackground)
    public static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
    public static let separator = Color(UIColor.separator)

    // MARK: - Surfaces

    public static let surface = dynamic(light: 0xFBF9F4, dark: 0x0E0E10)
    public static let surfaceElevated = dynamic(light: 0xFFFFFF, dark: 0x1A1A1C)
    public static let glassTint = dynamicAlpha(light: 0xFFFFFF, lightAlpha: 0.55,
                                               dark: 0x2C2C2E, darkAlpha: 0.35)
    public static let divider = dynamicAlpha(light: 0x000000, lightAlpha: 0.06,
                                             dark: 0xFFFFFF, darkAlpha: 0.08)

    // MARK: - Mood

    /// Soft pastel mapped to `Mood.rawValue` (1…5). Out-of-range → neutral.
    public static func mood(level: Int) -> Color {
        switch level {
        case 1: return dynamic(light: 0x8892B0, dark: 0x6B7496) // veryLow  — cool blue
        case 2: return dynamic(light: 0xA89CC0, dark: 0x857AA0) // low      — lavender
        case 3: return dynamic(light: 0xC9B89D, dark: 0xA89880) // neutral  — warm sand
        case 4: return dynamic(light: 0xE0A58F, dark: 0xC08670) // good     — terracotta
        case 5: return dynamic(light: 0x9FB889, dark: 0x7E9A6B) // veryGood — sage
        default: return dynamic(light: 0xC9B89D, dark: 0xA89880)
        }
    }

    /// Translucent variant for wash/tint backgrounds.
    public static func moodSoft(level: Int) -> Color {
        mood(level: level).opacity(0.22)
    }

    /// Used when an entry has no mood set — soft neutral that blends in.
    public static let moodUnknown = dynamic(light: 0xD8D3CB, dark: 0x3A3A3C)

    // MARK: - Accents (free + Pro)

    /// Pro-only preset accents. Picked to be visually distinct from the
    /// five free mood-aliased accents so the upgrade feels like a real
    /// expansion of the palette, not a reshuffle.
    public static func proAccent(_ accent: ProAccent) -> Color {
        switch accent {
        case .rose:   return dynamic(light: 0xC76A8E, dark: 0xE49AB4)
        case .ocean:  return dynamic(light: 0x2C5F7A, dark: 0x6FA3BF)
        case .forest: return dynamic(light: 0x3F6B47, dark: 0x7FAA85)
        case .gold:   return dynamic(light: 0xB68A3F, dark: 0xD9B567)
        case .plum:   return dynamic(light: 0x6B4079, dark: 0xB18EC3)
        }
    }

    /// Resolves the active tint colour for `AppearanceSettings`.
    /// Priority: customAccentHex (Pro) > proAccent (Pro) > accent (free).
    /// Invalid hex strings degrade to the free accent rather than throw,
    /// so a corrupt persisted value can't break rendering.
    public static func tintColor(for settings: AppearanceSettings) -> Color {
        if let hex = settings.customAccentHex,
           let uiColor = UIColor(hexString: hex) {
            return Color(uiColor: uiColor)
        }
        if let pro = settings.proAccent {
            return proAccent(pro)
        }
        return mood(level: settings.accent.rawValue)
    }

    // MARK: - Entry text color

    /// Resolves an `EntryTextColor` (preset or custom hex) to a concrete
    /// `Color` that adapts to light/dark mode for presets.
    public static func textColor(_ color: EntryTextColor) -> Color {
        switch color {
        case .preset(let preset):
            return presetTextColor(preset)
        case .custom(let hex):
            guard let uiColor = UIColor(hexString: hex) else { return primaryText }
            return Color(uiColor: uiColor)
        }
    }

    private static func presetTextColor(_ preset: EntryTextColor.Preset) -> Color {
        switch preset {
        case .default: return primaryText
        case .muted:   return secondaryText
        case .warm:    return dynamic(light: 0x9A6D3E, dark: 0xCFA982)
        case .cool:    return dynamic(light: 0x3F5B73, dark: 0x90A8BB)
        case .rose:    return dynamic(light: 0xB64F7E, dark: 0xE49AB4)
        case .forest:  return dynamic(light: 0x4A6F4A, dark: 0x88B58C)
        case .plum:    return dynamic(light: 0x6B3D7A, dark: 0xBC9DC8)
        case .rust:    return dynamic(light: 0x933B1A, dark: 0xD98368)
        }
    }

    /// Non-adaptive preview swatch for the Text Style sheet. Uses the light
    /// variant so swatches are recognisable regardless of current mode.
    public static func textColorSwatch(_ preset: EntryTextColor.Preset) -> Color {
        switch preset {
        case .default: return Color(UIColor(hex: 0x2B2B2E))
        case .muted:   return Color(UIColor(hex: 0x8A8A90))
        case .warm:    return Color(UIColor(hex: 0x9A6D3E))
        case .cool:    return Color(UIColor(hex: 0x3F5B73))
        case .rose:    return Color(UIColor(hex: 0xB64F7E))
        case .forest:  return Color(UIColor(hex: 0x4A6F4A))
        case .plum:    return Color(UIColor(hex: 0x6B3D7A))
        case .rust:    return Color(UIColor(hex: 0x933B1A))
        }
    }

    // MARK: - Dynamic helpers

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func dynamicAlpha(light: UInt32, lightAlpha: CGFloat,
                                     dark: UInt32, darkAlpha: CGFloat) -> Color {
        Color(UIColor { trait in
            let isDark = trait.userInterfaceStyle == .dark
            return UIColor(hex: isDark ? dark : light,
                           alpha: isDark ? darkAlpha : lightAlpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    convenience init?(hexString: String) {
        var trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
            return nil
        }
        self.init(hex: value)
    }
}
