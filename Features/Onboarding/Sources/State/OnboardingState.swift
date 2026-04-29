import Foundation
import Observation

@MainActor
@Observable
public final class OnboardingState {
    public enum Step: Int, CaseIterable, Sendable {
        case welcome
        case privacy
        case ai
        case diagnostics
        case permissions

        public var isLast: Bool { self == Self.allCases.last }
    }

    /// Unified state for every onboarding permission. An answered
    /// permission — whether `.granted` or `.denied` — counts as a
    /// decision, so the CTA unlocks once the user has made a call on
    /// both. Notification mapping absorbs `UNAuthorizationStatus`
    /// internally; biometric flips to `.denied` on any auth failure
    /// (including user cancel).
    public enum PermissionStatus: Sendable, Equatable {
        case notAsked
        case granted
        case denied
    }

    public var current: Step = .welcome
    public private(set) var notificationStatus: PermissionStatus = .notAsked
    public private(set) var biometricStatus: PermissionStatus = .notAsked

    /// Diagnostics consent toggles, bound directly by the onboarding
    /// page. Defaults to OFF; the final values are persisted when the
    /// user advances past `.diagnostics`.
    public var analyticsEnabled: Bool = false
    public var crashReportingEnabled: Bool = false

    public init() {}

    public var allPermissionsAnswered: Bool {
        notificationStatus != .notAsked && biometricStatus != .notAsked
    }

    public func advance() {
        guard let next = Step(rawValue: current.rawValue + 1) else { return }
        current = next
    }

    public func setNotificationStatus(_ status: PermissionStatus) {
        notificationStatus = status
    }

    public func setBiometricStatus(_ status: PermissionStatus) {
        biometricStatus = status
    }
}
