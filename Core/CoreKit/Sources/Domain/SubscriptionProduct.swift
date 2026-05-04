import Foundation

/// Display metadata for a single subscription SKU surfaced on the paywall.
/// Pricing strings are pre-formatted by the implementation (StoreKit's
/// `Product.displayPrice`) so the UI never does manual currency math.
public struct SubscriptionProduct: Identifiable, Sendable, Hashable {
    public typealias ID = String

    /// App Store product identifier (e.g. `com.veilbytesoft.Mira.pro.monthly`).
    public let id: ID

    /// Plan classification — drives ordering and "save X%" copy on the
    /// paywall.
    public let plan: SubscriptionPlan

    /// Localised product name from App Store Connect.
    public let displayName: String

    /// Pre-formatted, locale-aware price string (e.g. "$5.99", "599 ₽").
    public let displayPrice: String

    /// Raw decimal price in `currencyCode`. Surfaced so the paywall can
    /// compute cross-plan deltas ("save N% on yearly") without parsing
    /// `displayPrice`. Optional because some test catalogs don't expose it.
    public let price: Decimal?

    /// ISO 4217 currency code, useful for analytics bucketing. Optional
    /// because some test catalogs don't expose it.
    public let currencyCode: String?

    /// Introductory offer attached to the product, if any. Mira Pro ships
    /// with a 7-day free trial on first purchase.
    public let introductoryOffer: IntroductoryOffer?

    public init(
        id: ID,
        plan: SubscriptionPlan,
        displayName: String,
        displayPrice: String,
        price: Decimal? = nil,
        currencyCode: String?,
        introductoryOffer: IntroductoryOffer?
    ) {
        self.id = id
        self.plan = plan
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = currencyCode
        self.introductoryOffer = introductoryOffer
    }

    /// Apple introductory offer descriptor. Mirrors the three kinds StoreKit 2
    /// supports so the paywall can render the right copy ("Free for 7 days",
    /// "$2.99 for 3 months", etc.).
    public struct IntroductoryOffer: Sendable, Hashable {
        public enum Kind: Sendable, Hashable {
            case freeTrial(days: Int)
            case payAsYouGo(displayPrice: String, periods: Int)
            case payUpFront(displayPrice: String)
        }

        public let kind: Kind

        public init(kind: Kind) {
            self.kind = kind
        }
    }
}
