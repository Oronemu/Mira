import SwiftUI

private struct SubscriptionServiceKey: EnvironmentKey {
    static let defaultValue: any SubscriptionService = UnimplementedSubscriptionService()
}

public extension EnvironmentValues {
    var subscriptionService: any SubscriptionService {
        get { self[SubscriptionServiceKey.self] }
        set { self[SubscriptionServiceKey.self] = newValue }
    }
}
