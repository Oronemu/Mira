import Foundation
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` for Mira-owned alerts.
/// All text passes through `String(localized:)` so the usual xcstrings
/// pipeline picks up EN/RU translations.
public struct NotificationService: Sendable {
    public init() {}

    @discardableResult
    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func postReflectionReady(insightID: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Reflection ready")
        content.body = String(localized: "Your weekly reflection is waiting in Mira.")
        content.userInfo = ["insightID": insightID.uuidString]
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "mira.reflection.\(insightID.uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
