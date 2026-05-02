import Foundation

/// Billing cadence for a Mira Pro subscription. The set is intentionally
/// closed — Mira Pro ships with two plans, monthly and yearly, with no
/// lifetime tier. App Store product IDs map 1:1 to cases via
/// `appStoreProductID`.
public enum SubscriptionPlan: String, Sendable, Hashable, Codable, CaseIterable {
    case monthly
    case yearly

    /// App Store Connect product identifier. Must match the IDs configured
    /// for the app's auto-renewable subscription group.
    public var appStoreProductID: String {
        switch self {
        case .monthly: "com.veilbytesoft.Mira.pro.monthly"
        case .yearly: "com.veilbytesoft.Mira.pro.yearly"
        }
    }
}
