import SwiftUI

private struct PushNotificationServiceKey: EnvironmentKey {
    static let defaultValue: any PushNotificationService = UnimplementedPushNotificationService()
}

public extension EnvironmentValues {
    var pushNotificationService: any PushNotificationService {
        get { self[PushNotificationServiceKey.self] }
        set { self[PushNotificationServiceKey.self] = newValue }
    }
}
