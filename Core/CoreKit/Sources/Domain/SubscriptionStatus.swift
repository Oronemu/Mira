import Foundation

/// Snapshot of the user's current Pro entitlement state. Designed to be
/// trivially `Equatable` so SwiftUI can diff it for `.onChange` updates.
///
/// `unknown` exists for the brief window between app launch and the first
/// successful StoreKit / backend round-trip; UI should treat it as "loading"
/// rather than "free" to avoid flashing the paywall on warm launches.
public enum SubscriptionStatus: Sendable, Hashable {
    case unknown
    case free
    case pro(Pro)

    /// Active Pro entitlement details. Carries the source so callers can
    /// distinguish a paying customer from a granted one (e.g. for analytics
    /// or diagnostic display in Settings).
    public struct Pro: Sendable, Hashable {
        public let plan: SubscriptionPlan
        public let renewalDate: Date?
        public let isInTrial: Bool
        public let source: Source

        public init(
            plan: SubscriptionPlan,
            renewalDate: Date?,
            isInTrial: Bool,
            source: Source
        ) {
            self.plan = plan
            self.renewalDate = renewalDate
            self.isInTrial = isInTrial
            self.source = source
        }

        /// Where the entitlement came from. Drives Settings copy
        /// ("Subscribed via App Store", "Granted by code", etc.) and
        /// determines whether "Manage Subscription" is shown.
        public enum Source: Sendable, Hashable {
            case appStore
            case testFlight
            case redeemCode(String)
            case appleOfferCode
        }
    }

    /// Convenience: `true` if the user currently has Pro access. UI gates
    /// should prefer `SubscriptionService.isEntitled(to:)` when checking a
    /// specific feature, since future tiers may carve out different sets.
    public var isPro: Bool {
        if case .pro = self { return true } else { return false }
    }

    /// Convenience: pull the Pro payload, if any.
    public var proDetails: Pro? {
        if case let .pro(details) = self { return details } else { return nil }
    }
}
