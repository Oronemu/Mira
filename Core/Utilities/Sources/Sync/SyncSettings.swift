import Foundation

public struct SyncSettings: Sendable, Hashable, Codable {
    public var isEnabled: Bool

    public init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }
}

public extension SyncSettings {
    static let `default` = SyncSettings()
}

public struct SyncSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "sync.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> SyncSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(SyncSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: SyncSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
