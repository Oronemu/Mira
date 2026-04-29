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

public struct AppearanceSettings: Sendable, Hashable, Codable {
    public var theme: AppearanceTheme
    public var accent: AccentTint

    public init(theme: AppearanceTheme = .system, accent: AccentTint = .sand) {
        self.theme = theme
        self.accent = accent
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
