import Foundation

public enum BiometricMode: String, Sendable, Hashable, Codable, CaseIterable {
    /// No lock at all.
    case off
    /// Lock only after the app has spent more than the soft window in the
    /// background. Allows quick app switches without re-authenticating.
    case soft
    /// Lock on every cold launch and any background return beyond the
    /// soft window.
    case always
}

public struct BiometricSettings: Sendable, Hashable, Codable {
    public var mode: BiometricMode

    public init(mode: BiometricMode = .off) {
        self.mode = mode
    }
}

public extension BiometricSettings {
    static let `default` = BiometricSettings()
    /// Background window after which `.soft` also demands re-auth.
    static let backgroundSoftWindow: TimeInterval = 60
}

public struct BiometricSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "biometric.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> BiometricSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(BiometricSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: BiometricSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
