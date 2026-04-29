import SwiftUI

private struct SyncServiceKey: EnvironmentKey {
    static let defaultValue = SyncService()
}

public extension EnvironmentValues {
    /// The app-wide sync façade. Defaults to a stub that only encrypts
    /// nothing and reports `.succeeded` — previews and unit tests that
    /// don't care about CloudKit pick up this default without any
    /// additional wiring. The real `SyncService` (with configured
    /// pusher/puller/tokens) is injected from `ServiceContainer.live()`.
    var syncService: SyncService {
        get { self[SyncServiceKey.self] }
        set { self[SyncServiceKey.self] = newValue }
    }
}
