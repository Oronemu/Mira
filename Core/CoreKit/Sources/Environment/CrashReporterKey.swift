import SwiftUI

private struct CrashReporterKey: EnvironmentKey {
    static let defaultValue: any CrashReporter = UnimplementedCrashReporter()
}

public extension EnvironmentValues {
    var crashReporter: any CrashReporter {
        get { self[CrashReporterKey.self] }
        set { self[CrashReporterKey.self] = newValue }
    }
}
