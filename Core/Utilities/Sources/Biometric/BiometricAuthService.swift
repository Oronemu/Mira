import Foundation
import LocalAuthentication

public enum BiometricError: Error, LocalizedError, Sendable {
    case unavailable
    case cancelled
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable: String(localized: "Biometric authentication is not available on this device.")
        case .cancelled: String(localized: "Authentication cancelled.")
        case .failed(let message): message
        }
    }
}

/// Hardware biometry available on the current device.
public enum BiometryKind: Sendable, Hashable {
    case none
    case faceID
    case touchID
    case opticID
    case passcodeOnly
}

/// Thin LocalAuthentication wrapper. Default policy allows device passcode
/// as a fallback; callers that specifically ask for biometrics (e.g. the
/// onboarding "Enable Face ID lock" opt-in) can pass `.biometricsOnly` so
/// a declined Face ID prompt doesn't silently succeed via passcode.
public struct BiometricAuthService: Sendable {
    public enum AuthPolicy: Sendable {
        /// Biometrics with passcode fallback. Right for unlock flows where
        /// we only care that the device owner is present.
        case deviceOwner
        /// Strictly biometrics — no passcode fallback. A declined prompt
        /// is surfaced as a cancellation, which is what the onboarding
        /// opt-in actually wants to observe.
        case biometricsOnly

        fileprivate var laPolicy: LAPolicy {
            switch self {
            case .deviceOwner:     return .deviceOwnerAuthentication
            case .biometricsOnly:  return .deviceOwnerAuthenticationWithBiometrics
            }
        }
    }

    public init() {}

    public var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Best-effort detection of the biometry hardware. Use to label the
    /// unlock affordance ("Use Face ID" vs "Use Touch ID"). Evaluating the
    /// policy first is required before `biometryType` is populated.
    public var biometryKind: BiometryKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        case .none: return .passcodeOnly
        @unknown default: return .passcodeOnly
        }
    }

    public func authenticate(reason: String, policy: AuthPolicy = .deviceOwner) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(policy.laPolicy, error: &error) else {
            throw BiometricError.unavailable
        }
        do {
            let success = try await context.evaluatePolicy(
                policy.laPolicy,
                localizedReason: reason
            )
            if !success { throw BiometricError.cancelled }
        } catch let laError as LAError where laError.code == .userCancel || laError.code == .appCancel || laError.code == .systemCancel || laError.code == .userFallback {
            throw BiometricError.cancelled
        } catch {
            throw BiometricError.failed(error.localizedDescription)
        }
    }
}
