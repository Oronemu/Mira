import Foundation

/// Push notification lifecycle. The implementation is expected to bridge
/// APNs tokens to FCM and to expose the FCM registration token for
/// server-side targeting.
public protocol PushNotificationService: Sendable {
    /// Request system notification authorization. Returns `true` if the
    /// user granted (or had previously granted) any non-.none permission.
    func requestAuthorization() async -> Bool

    /// Register with APNs. Safe to call every launch — iOS deduplicates.
    /// Must be invoked from the main actor (implementation hops as needed).
    func registerForRemoteNotifications() async

    /// Called from `UIApplicationDelegate` once APNs hands back a token.
    /// The implementation forwards the raw token to Firebase Messaging.
    func applyAPNsToken(_ token: Data)

    /// Latest FCM registration token, if the SDK has obtained one yet.
    func currentFCMToken() async -> String?

    /// Stream of FCM token refreshes. Fires every time Firebase issues
    /// a new registration token (initial issuance, restore, reinstall,
    /// data reset). Subscribers should register the new token with
    /// whatever backend stores per-install push targets.
    func tokenRefreshes() -> AsyncStream<String>

    /// Subscribe this install to a topic-based broadcast (e.g. "ru").
    func subscribe(toTopic topic: String) async throws

    /// Unsubscribe from a previously subscribed topic.
    func unsubscribe(fromTopic topic: String) async throws
}
