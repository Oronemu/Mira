import Foundation

/// User consent for Firebase-backed product telemetry. Both toggles
/// default to `false` — Info.plist also switches off Firebase's
/// automatic collection until the runtime flip in `MiraApp.init` turns
/// each on. `hasAnswered` tells the onboarding flow whether we've ever
/// asked the user; a fresh install returns `false`.
public struct DiagnosticsSettings: Sendable, Hashable, Codable {
    public var analyticsEnabled: Bool
    public var crashReportingEnabled: Bool
    public var hasAnswered: Bool

    public init(
        analyticsEnabled: Bool = false,
        crashReportingEnabled: Bool = false,
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
