import Foundation

/// No-op fallback for previews, tests, and the default environment.
public struct UnimplementedPushNotificationService: PushNotificationService {
    public init() {}

    public func requestAuthorization() async -> Bool { false }
    public func registerForRemoteNotifications() async {}
    public func applyAPNsToken(_ token: Data) {}
    public func currentFCMToken() async -> String? { nil }
    public func tokenRefreshes() -> AsyncStream<String> {
        AsyncStream { $0.finish() }
    }
    public func subscribe(toTopic topic: String) async throws {}
    public func unsubscribe(fromTopic topic: String) async throws {}
}
