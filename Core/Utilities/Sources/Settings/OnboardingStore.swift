import Foundation

/// Tiny UserDefaults-backed flag for "user has seen onboarding". Kept
/// in Utilities so both the App composition root and feature modules
/// can read it without pulling in heavier state types.
public struct OnboardingStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "onboarding.completed") {
        self.defaults = defaults
        self.key = key
    }

    public var isCompleted: Bool {
        get { defaults.bool(forKey: key) }
        nonmutating set { defaults.set(newValue, forKey: key) }
    }
}
