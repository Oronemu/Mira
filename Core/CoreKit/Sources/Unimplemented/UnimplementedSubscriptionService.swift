import Foundation

/// Default `SubscriptionService` used as the environment fallback. Reports
/// the user as Free and refuses every mutating operation — production paths
/// must inject a real implementation through `ServiceContainer`. Tests and
/// previews should pick `MockSubscriptionService` from `TestSupport` or the
/// in-memory developer service from the `Subscriptions` module instead.
public struct UnimplementedSubscriptionService: SubscriptionService {
    public init() {}

    public var status: SubscriptionStatus { .free }

    public var statusUpdates: AsyncStream<SubscriptionStatus> {
        AsyncStream { continuation in continuation.finish() }
    }

    public func isEntitled(to entitlement: ProEntitlement) async -> Bool { false }

    public func availableProducts() async throws -> [SubscriptionProduct] { [] }

    public func purchase(productID: SubscriptionProduct.ID) async throws -> SubscriptionStatus {
        throw SubscriptionError.unimplemented
    }

    public func restorePurchases() async throws -> SubscriptionStatus {
        throw SubscriptionError.unimplemented
    }

    public func redeem(code: String) async throws -> SubscriptionStatus {
        throw SubscriptionError.unimplemented
    }

    public func refresh() async {}

    public func latestSignedTransaction() async -> String? { nil }

    public var redeemUserID: String? { nil }

    public func fetchUsage() async throws -> UsageSnapshot {
        throw SubscriptionError.unimplemented
    }
}
