import Foundation

public struct ScreenShieldSettings: Sendable, Hashable, Codable {
    public var isEnabled: Bool

    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
}

public extension ScreenShieldSettings {
    static let `default` = ScreenShieldSettings()
}

public struct ScreenShieldSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "screen-shield.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> ScreenShieldSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ScreenShieldSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: ScreenShieldSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
