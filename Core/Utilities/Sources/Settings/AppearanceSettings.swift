import Foundation

public enum AppearanceTheme: String, Sendable, Hashable, Codable, CaseIterable {
    case system
    case light
    case dark
}

public enum AccentTint: Int, Sendable, Hashable, Codable, CaseIterable {
    case cool = 1
    case lavender = 2
    case sand = 3
    case clay = 4
    case sage = 5
}

/// Additional accents unlocked by Mira Pro. Stored alongside the free
/// `AccentTint` rather than replacing it so existing settings stay
/// valid: when a Pro accent is selected, `proAccent != nil` overrides
/// the free one for resolution.
public enum ProAccent: String, Sendable, Hashable, Codable, CaseIterable {
    case rose
    case ocean
    case forest
    case gold
    case plum
}

public struct AppearanceSettings: Sendable, Hashable, Codable {
    public var theme: AppearanceTheme
    public var accent: AccentTint
    /// When set, overrides `accent` with a Pro preset. `nil` means the
    /// free `accent` field drives the tint.
    public var proAccent: ProAccent?
    /// `#RRGGBB` for a Pro custom-color tint. Highest priority — wins
    /// over both `proAccent` and `accent` when present and parseable.
    public var customAccentHex: String?

    public init(
        theme: AppearanceTheme = .system,
        accent: AccentTint = .sand,
        proAccent: ProAccent? = nil,
        customAccentHex: String? = nil
    ) {
        self.theme = theme
        self.accent = accent
        self.proAccent = proAccent
        self.customAccentHex = customAccentHex
    }

    /// Custom decoder so settings persisted before the Pro fields
    /// landed still load — `decodeIfPresent` defaults the new keys to
    /// nil instead of failing the whole read.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.theme = try container.decodeIfPresent(AppearanceTheme.self, forKey: .theme) ?? .system
        self.accent = try container.decodeIfPresent(AccentTint.self, forKey: .accent) ?? .sand
        self.proAccent = try container.decodeIfPresent(ProAccent.self, forKey: .proAccent)
        self.customAccentHex = try container.decodeIfPresent(String.self, forKey: .customAccentHex)
    }
}

public extension AppearanceSettings {
    static let `default` = AppearanceSettings()
}

public struct AppearanceSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "appearance.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AppearanceSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppearanceSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: AppearanceSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
