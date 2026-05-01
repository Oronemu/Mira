import Foundation

/// User consent for Firebase-backed product telemetry. Toggles default
/// to ON so the diagnostics step in onboarding starts in the opt-out
/// position. Info.plist still keeps Firebase's automatic collection
/// switched off until `MiraApp.init` flips each on, and the flip only
/// happens once `hasAnswered` is true — so a fresh install that hasn't
/// reached the diagnostics step yet keeps Firebase silent.
public struct DiagnosticsSettings: Sendable, Hashable, Codable {
    public var analyticsEnabled: Bool
    public var crashReportingEnabled: Bool
    public var hasAnswered: Bool

    public init(
        analyticsEnabled: Bool = true,
        crashReportingEnabled: Bool = true,
        hasAnswered: Bool = false
    ) {
        self.analyticsEnabled = analyticsEnabled
        self.crashReportingEnabled = crashReportingEnabled
        self.hasAnswered = hasAnswered
    }
}

public extension DiagnosticsSettings {
    static let `default` = DiagnosticsSettings()
}

public struct DiagnosticsSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "diagnostics.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> DiagnosticsSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(DiagnosticsSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: DiagnosticsSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
