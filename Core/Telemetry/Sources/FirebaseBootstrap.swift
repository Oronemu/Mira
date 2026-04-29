import Foundation
@preconcurrency import FirebaseCore

/// One-shot Firebase initialisation. Must be called exactly once, as early
/// in app launch as possible (before any Firebase SDK is used). Subsequent
/// calls are no-ops.
public enum FirebaseBootstrap {
    private static let hasConfigured = Locked(false)

    /// Configure the default FirebaseApp from the bundled
    /// `GoogleService-Info.plist`. Safe to call multiple times.
    public static func configure() {
        hasConfigured.withLock { configured in
            guard !configured else { return }
            FirebaseApp.configure()
            configured = true
        }
    }
}

/// Tiny lock wrapper so the one-shot flag is safe to flip from any thread
/// without pulling in a whole dependency.
private final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func withLock(_ body: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&value)
    }
}
