import Foundation

/// Source of truth for the user's Pro entitlement. The protocol is the only
/// surface feature modules should ever touch — StoreKit, the Cloudflare
/// Worker, and any future replacement (RevenueCat, custom backend) sit
/// behind it. Following the project's "Environment-based DI" pattern, an
/// instance is published as `EnvironmentValues.subscriptionService`.
///
/// All operations are async and Sendable-safe so they can be called from
/// `@MainActor` view code without fighting Swift 6 concurrency. Callers
/// should treat `status` as "best known so far" — for guards that absolutely
/// must reflect server truth (e.g. before calling the hosted AI proxy),
/// they should `await` `refresh()` first.
public protocol SubscriptionService: Sendable {
    /// Latest known entitlement snapshot. May be `.unknown` immediately
    /// after launch until the first refresh completes.
    var status: SubscriptionStatus { get async }

    /// Long-lived stream of status changes — typically backed by StoreKit's
    /// `Transaction.updates`. View state containers consume it from `.task`
    /// so paywall gating reacts in real time to purchases, expirations and
    /// refunds.
    var statusUpdates: AsyncStream<SubscriptionStatus> { get }

    /// Returns `true` if the user can use the given Pro capability right
    /// now. Implementations may consider granular tiers in the future; on
    /// v1 every Pro entitlement is unlocked together.
    func isEntitled(to entitlement: ProEntitlement) async -> Bool

    /// Catalogued products surfaced on the paywall, in display order.
    /// Throws on network or StoreKit errors so the UI can show a retry
    /// banner instead of an empty list.
    func availableProducts() async throws -> [SubscriptionProduct]

    /// Initiates a purchase via StoreKit. Returns the post-transaction
    /// status (typically `.pro(...)` on success, `.free` on a verification
    /// failure that should not throw). Throws `SubscriptionError` for
    /// user-cancellation, network, and verification problems.
    @discardableResult
    func purchase(productID: SubscriptionProduct.ID) async throws -> SubscriptionStatus

    /// Triggers `AppStore.sync()` and re-evaluates entitlements. Used by
    /// the "Restore Purchases" button.
    @discardableResult
    func restorePurchases() async throws -> SubscriptionStatus

    /// Applies a developer-issued grant code (delivered out-of-band, e.g.
    /// over email). Validation lives on the Cloudflare Worker; the client
    /// only forwards the code and trusts the server response. Phase 1
    /// implementations may stub this with an in-memory whitelist.
    @discardableResult
    func redeem(code: String) async throws -> SubscriptionStatus

    /// Forces a fresh fetch of entitlements. Cheap to call repeatedly —
    /// implementations should debounce internally.
    func refresh() async

    /// JWS for the currently active StoreKit transaction, if any. The
    /// hosted AI client passes this to the Cloudflare Worker so the
    /// server can verify the user really paid before forwarding to
    /// Anthropic. Returns `nil` for free users, mock/in-memory
    /// implementations, and any state where StoreKit hasn't issued a
    /// verified transaction yet.
    func latestSignedTransaction() async -> String?

    /// Device-bound identifier stored after a successful custom redeem
    /// code grant. The hosted AI client sends this as `redeemUserId`
    /// when no StoreKit JWS is available. Returns `nil` when the user
    /// never redeemed a custom code.
    var redeemUserID: String? { get async }

    /// Fetches the caller's current monthly usage against hosted-AI
    /// caps. The Pro settings screen calls this to render "X of Y left
    /// this month" without having to poll the AI endpoint. Throws if
    /// the caller has no entitlement (`SubscriptionError.unimplemented`
    /// for stub services, network/verification cases otherwise).
    func fetchUsage() async throws -> UsageSnapshot
}
