import Foundation

public struct EveningReminderPrefs: Sendable, Hashable, Codable {
    public var isEnabled: Bool
    public var hour: Int
    public var minute: Int

    public init(isEnabled: Bool = true, hour: Int = 21, minute: Int = 30) {
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
    }

    public static let `default` = EveningReminderPrefs()
}

public struct InactivityNudgePrefs: Sendable, Hashable, Codable {
    public var isEnabled: Bool
    public var thresholdDays: Int
    public var hour: Int
    public var minute: Int

    public init(
        isEnabled: Bool = true,
        thresholdDays: Int = 3,
        hour: Int = 10,
        minute: Int = 0
    ) {
        self.isEnabled = isEnabled
        self.thresholdDays = thresholdDays
        self.hour = hour
        self.minute = minute
    }

    public static let `default` = InactivityNudgePrefs()
}

public struct NotificationPreferences: Sendable, Hashable, Codable {
    public var evening: EveningReminderPrefs
    public var inactivity: InactivityNudgePrefs

    public init(
        evening: EveningReminderPrefs = .default,
        inactivity: InactivityNudgePrefs = .default
    ) {
        self.evening = evening
        self.inactivity = inactivity
    }

    public static let `default` = NotificationPreferences()
}

public struct NotificationPreferencesStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "notifications.preferences"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> NotificationPreferences {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ prefs: NotificationPreferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: key)
    }
}
