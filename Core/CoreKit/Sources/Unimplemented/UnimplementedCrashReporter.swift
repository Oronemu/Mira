import Foundation

/// No-op fallback for previews, tests, and the default environment.
public struct UnimplementedCrashReporter: CrashReporter {
    public init() {}

    public func recordError(_ error: Error, reason: String?) {}
    public func log(_ message: String) {}
    public func setEnabled(_ enabled: Bool) {}
}
