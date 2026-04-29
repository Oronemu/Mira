import SwiftUI

private struct ModelDownloadCoordinatorKey: EnvironmentKey {
    // EnvironmentKey requires a nonisolated `defaultValue`, but
    // ModelDownloadCoordinator is @MainActor-isolated. The lazy-init
    // closure is only evaluated on first access, which SwiftUI always
    // performs from the MainActor when reading EnvironmentValues during
    // view updates. `MainActor.assumeIsolated` trades the compile-time
    // check for a runtime assertion that's safe in practice.
    static let defaultValue: ModelDownloadCoordinator = {
        MainActor.assumeIsolated { ModelDownloadCoordinator() }
    }()
}

public extension EnvironmentValues {
    var modelDownloadCoordinator: ModelDownloadCoordinator {
        get { self[ModelDownloadCoordinatorKey.self] }
        set { self[ModelDownloadCoordinatorKey.self] = newValue }
    }
}
