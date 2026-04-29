import Foundation

/// No-op fallback used in previews, tests, and as the default environment
/// value. Never ships in production — `ServiceContainer.live()` replaces it
/// with the Firebase-backed implementation from the Telemetry module.
public struct UnimplementedAnalyticsService: AnalyticsService {
    public init() {}

    public func log(event: String, parameters: [String: AnalyticsParameterValue]) {}
    public func setUserProperty(_ value: String?, forName name: String) {}
    public func setEnabled(_ enabled: Bool) {}
}
