import Foundation
import Observation
import SwiftUI
import Utilities

@MainActor
@Observable
final class LockState {
    private(set) var isLocked: Bool
    private(set) var isAuthenticating: Bool = false
    private(set) var lastError: String?
    private var backgroundedAt: Date?

    private let store = BiometricSettingsStore()
    private let auth = BiometricAuthService()

    var biometryKind: BiometryKind { auth.biometryKind }

    init() {
        // Decide lock state synchronously at startup so the lock screen is
        // visible on the very first render — otherwise the privacy shield
        // (if enabled) briefly covers the Face ID prompt on cold launch.
        let mode = BiometricSettingsStore().load().mode
        self.isLocked = (mode == .always)
    }

    func handle(scenePhase newPhase: ScenePhase) {
        let mode = store.load().mode
        guard mode != .off else { return }
        switch newPhase {
        case .background:
            backgroundedAt = .now
        case .active:
            defer { backgroundedAt = nil }
            guard let backgroundedAt else { return }
            let elapsed = Date.now.timeIntervalSince(backgroundedAt)
            if elapsed >= BiometricSettings.backgroundSoftWindow {
                isLocked = true
            }
        default:
            break
        }
    }

    func attemptUnlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }
        do {
            try await auth.authenticate(reason: String(localized: "Unlock Mira"))
            isLocked = false
        } catch BiometricError.cancelled {
            // Stay locked; user can retry manually.
        } catch {
            lastError = error.localizedDescription
        }
    }
}
