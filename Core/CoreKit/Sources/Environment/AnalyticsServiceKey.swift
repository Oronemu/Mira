import SwiftUI

private struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: any AnalyticsService = UnimplementedAnalyticsService()
}

public extension EnvironmentValues {
    var analyticsService: any AnalyticsService {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}
