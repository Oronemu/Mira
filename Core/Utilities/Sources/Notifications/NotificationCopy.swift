import Foundation

/// One title + body pair shown to the user. Pairs are authored as a unit
/// so the title and body match in tone.
public struct NotificationCopy: Sendable, Hashable, Codable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Source of localized, optionally remote-overridden notification copy.
public protocol NotificationCopyProvider: Sendable {
    func copy(for kind: LocalNotificationKind, on date: Date, locale: Locale) async -> NotificationCopy
}
