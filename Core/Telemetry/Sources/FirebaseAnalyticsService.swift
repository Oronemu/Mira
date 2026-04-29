import Foundation
import CoreKit
@preconcurrency import FirebaseAnalytics

/// Firebase-backed `AnalyticsService`. `FIRAnalytics` itself is thread-safe
/// (internally dispatches onto its own queue), so this struct can be
/// nonisolated and `Sendable`.
public struct FirebaseAnalyticsService: AnalyticsService {
    public init() {}

    public func log(event: String, parameters: [String: AnalyticsParameterValue]) {
        let bridged = parameters.isEmpty ? nil : parameters.mapValues(Self.bridge(_:))
        Analytics.logEvent(event, parameters: bridged)
    }

    public func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    public func setEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    private static func bridge(_ value: AnalyticsParameterValue) -> NSObject {
        switch value {
        case .string(let string): return string as NSString
        case .int(let int): return NSNumber(value: int)
        case .double(let double): return NSNumber(value: double)
        case .bool(let bool): return NSNumber(value: bool)
        }
    }
}
