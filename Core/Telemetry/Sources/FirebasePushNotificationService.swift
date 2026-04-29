import Foundation
import UIKit
import UserNotifications
import os
import CoreKit
@preconcurrency import FirebaseMessaging

/// Firebase Cloud Messaging–backed `PushNotificationService`. Owns the
/// APNs → FCM token handoff; the App's `UIApplicationDelegate` must call
/// `applyAPNsToken(_:)` from `didRegisterForRemoteNotificationsWithDeviceToken`.
///
/// Conforms to `MessagingDelegate` so we receive token-refresh
/// callbacks from Firebase and surface them through `tokenRefreshes()`
/// for any subscriber (e.g. the App's launch logger or, later, a
/// backend register-this-install call). The class is an `NSObject`
/// because `MessagingDelegate` requires `NSObjectProtocol`. Mutable
/// state (the active stream continuation) is lock-protected, hence
/// `@unchecked Sendable`.
public final class FirebasePushNotificationService: NSObject, PushNotificationService, MessagingDelegate, @unchecked Sendable {
    private let continuation = OSAllocatedUnfairLock<AsyncStream<String>.Continuation?>(initialState: nil)

    public override init() {
        super.init()
        // Must run after `FirebaseApp.configure()` — the App's
        // composition root guarantees that ordering.
        Messaging.messaging().delegate = self
    }

    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    @MainActor
    public func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }

    public func applyAPNsToken(_ token: Data) {
        Messaging.messaging().apnsToken = token
    }

    public func currentFCMToken() async -> String? {
        await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                continuation.resume(returning: token)
            }
        }
    }

    public func tokenRefreshes() -> AsyncStream<String> {
        AsyncStream { newContinuation in
            self.continuation.withLock { existing in
                existing?.finish()
                existing = newContinuation
            }
            newContinuation.onTermination = { [weak self] _ in
                self?.continuation.withLock { $0 = nil }
            }
        }
    }

    public func subscribe(toTopic topic: String) async throws {
        try await Messaging.messaging().subscribe(toTopic: topic)
    }

    public func unsubscribe(fromTopic topic: String) async throws {
        try await Messaging.messaging().unsubscribe(fromTopic: topic)
    }

    // MARK: - MessagingDelegate

    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        continuation.withLock { $0?.yield(token) }
    }
}
