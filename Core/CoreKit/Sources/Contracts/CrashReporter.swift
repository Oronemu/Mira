import Foundation

/// Crash reporting and non-fatal error telemetry. Same privacy rule as
/// `AnalyticsService`: journal content must never reach this protocol.
public protocol CrashReporter: Sendable {
    /// Record a non-fatal error to the crash backend. `reason` is a short
    /// developer-authored string (no journal content).
    func recordError(_ error: Error, reason: String?)

    /// Append a breadcrumb log entry that will be attached to the next
    /// crash report. Keep messages short and content-free.
    func log(_ message: String)

    /// Master switch for crash reporting — wired to the in-app
    /// "Diagnostics & Analytics" toggle.
    func setEnabled(_ enabled: Bool)
}

public extension CrashReporter {
    /// Convenience: record an error without a reason string.
    func recordError(_ error: Error) {
        recordError(error, reason: nil)
    }
}
