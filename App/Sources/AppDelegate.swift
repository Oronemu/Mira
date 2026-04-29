import UIKit
import UserNotifications
import AIKit
import CoreKit
import Utilities

/// Minimal `UIApplicationDelegate` used to receive the APNs device
/// token and to route silent CloudKit pushes into the sync service.
/// SwiftUI owns the rest of the lifecycle via `@main struct MiraApp`.
/// Dependencies are injected once on launch via `configure`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    private var pushService: (any PushNotificationService)?
    private var syncService: SyncService?

    func configure(pushService: any PushNotificationService, syncService: SyncService) {
        self.pushService = pushService
        self.syncService = syncService
    }

    /// `FirebaseAppDelegateProxyEnabled` is `false` in our Info.plist, so
    /// Firebase doesn't auto-install itself as the
    /// `UNUserNotificationCenter` delegate. We do it here so foreground
    /// notifications can be presented and taps reach the app.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushService?.applyAPNsToken(deviceToken)
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        MiraLog.logger(.general).info("APNs token: \(hex, privacy: .public)")
        // Now that Firebase has the APNs token it can resolve the FCM
        // token. Querying earlier (e.g. in `bootstrapTelemetry`) races
        // against this callback and reliably comes back nil with
        // "APNS device token not set before retrieving FCM Token".
        guard let pushService else { return }
        Task {
            if let fcm = await pushService.currentFCMToken() {
                MiraLog.logger(.general).info("FCM token: \(fcm, privacy: .public)")
            } else {
                MiraLog.logger(.general).info("FCM token: nil (Firebase could not resolve)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        MiraLog.logger(.general).error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }

    /// Forwarded by iOS when the app is relaunched in the background to
    /// deliver `URLSession.background(...)` events for the model
    /// download session. We hand the completion handler to
    /// `BackgroundDownloadSession`, which fires it from
    /// `urlSessionDidFinishEvents(forBackgroundURLSession:)` once every
    /// queued delegate event has been processed.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == BackgroundDownloadSession.sessionIdentifier else {
            completionHandler()
            return
        }
        Task { @MainActor in
            BackgroundDownloadSession.shared.setBackgroundCompletionHandler(
                identifier: identifier,
                completionHandler
            )
        }
    }

    /// CloudKit subscriptions deliver silent pushes with a `ck` payload
    /// key; any notification with that marker means "something changed
    /// upstream, pull now". Everything else is ignored here (Firebase
    /// Messaging handles its own routing through AppDelegateProxy
    /// being disabled in Info.plist).
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard userInfo["ck"] != nil, let syncService else {
            completionHandler(.noData)
            return
        }
        Task {
            await syncService.sync()
            completionHandler(.newData)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Allow notifications to display while the app is in the
    /// foreground. Without this, banner + sound are silently swallowed
    /// by iOS for the active app.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// Tap / action handler. We don't deeplink yet, so just acknowledge
    /// — but having the delegate set means iOS routes the tap through
    /// here instead of dropping it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
