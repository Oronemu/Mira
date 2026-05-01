import Foundation

public enum LocalNotificationKind: String, CaseIterable, Sendable, Codable {
    case eveningReflection
    case inactivity
}

public extension LocalNotificationKind {
    /// Prefix for the Remote Config key holding overrides for this kind.
    /// Resolved per-language as `<prefix>_<lang>` (e.g. `notif_evening_ru`).
    var remoteConfigKeyPrefix: String {
        switch self {
        case .eveningReflection: "notif_evening"
        case .inactivity: "notif_inactivity"
        }
    }

    /// Prefix used when constructing `UNNotificationRequest` identifiers.
    /// Evening uses `<prefix>.<yyyy-MM-dd>`; inactivity uses the prefix
    /// alone since only one inactivity request is ever pending at a time.
    var notificationIdentifierPrefix: String {
        switch self {
        case .eveningReflection: "mira.notify.evening"
        case .inactivity: "mira.notify.inactivity"
        }
    }
}
