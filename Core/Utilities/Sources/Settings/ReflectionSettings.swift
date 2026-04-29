import Foundation

public enum ReflectionFrequency: String, Sendable, Hashable, Codable, CaseIterable {
    case off
    case weekly
    case biweekly
}

public struct ReflectionSettings: Sendable, Hashable, Codable {
    public var frequency: ReflectionFrequency

    public init(frequency: ReflectionFrequency = .weekly) {
        self.frequency = frequency
    }
}

public extension ReflectionSettings {
    static let `default` = ReflectionSettings()
}

public struct ReflectionSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "reflection.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> ReflectionSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ReflectionSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: ReflectionSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
