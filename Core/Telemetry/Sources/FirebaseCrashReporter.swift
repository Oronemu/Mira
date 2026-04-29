import Foundation
import CoreKit
@preconcurrency import FirebaseCrashlytics

/// Firebase-backed `CrashReporter`. `FIRCrashlytics` is a thread-safe
/// singleton.
public struct FirebaseCrashReporter: CrashReporter {
    public init() {}

    public func recordError(_ error: Error, reason: String?) {
        let crashlytics = Crashlytics.crashlytics()
        if let reason {
            crashlytics.record(
                error: error,
                userInfo: ["reason": reason]
            )
        } else {
            crashlytics.record(error: error)
        }
    }

    public func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    public func setEnabled(_ enabled: Bool) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    }
}
