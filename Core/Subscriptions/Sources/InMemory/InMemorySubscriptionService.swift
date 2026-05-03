import Foundation
import Observation
import CoreKit

/// `SubscriptionService` backed entirely by in-memory state — no StoreKit,
/// no network. It exists for two reasons:
///
/// 1. **Phase 1 wiring.** Until the real `StoreKitSubscriptionService`
///    lands (Phase 2), the app and tests need a concrete service that
///    serves the canonical product catalog and lets purchases "succeed"
///    so paywall plumbing can be exercised end-to-end on simulators.
/// 2. **Developer override.** A debug toggle in Settings can swap the live
///    service for this one to flip Pro on/off without touching App Store
///    sandbox. Convenient for screenshot runs and feature reviews.
///
/// The service is an actor so concurrent reads/writes from view code, the
/// transaction observer, and tests can't corrupt each other. Status updates
/// are broadcast through an `AsyncStream` so SwiftUI views can subscribe
/// from `.task` blocks.
public actor InMemorySubscriptionService: SubscriptionService {
    private var currentStatus: SubscriptionStatus
    private let products: [SubscriptionProduct]
    private var continuations: [UUID: AsyncStream<SubscriptionStatus>.Continuation] = [:]
    private let validRedeemCodes: Set<String>
    private var consumedRedeemCodes: Set<String> = []

    /// - Parameters:
    ///   - initialStatus: status to report from the moment the service is
    ///     constructed. Defaults to `.free` so the paywall behaves
    ///     realistically in dev builds.
    ///   - products: catalogued SKUs. Defaults to the canonical Mira Pro
    ///     monthly + yearly pair, both with a 7-day free trial.
    ///   - validRedeemCodes: codes that `redeem(_:)` will accept. Empty by
    ///     default — tests that exercise grant flows pass an explicit set.
    public init(
        initialStatus: SubscriptionStatus = .free,
        products: [SubscriptionProduct] = InMemorySubscriptionService.defaultProducts,
        validRedeemCodes: Set<String> = []
    ) {
        self.currentStatus = initialStatus
        self.products = products
        self.validRedeemCodes = validRedeemCodes
    }

    public var status: SubscriptionStatus { currentStatus }

    public nonisolated var statusUpdates: AsyncStream<SubscriptionStatus> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    public func isEntitled(to entitlement: ProEntitlement) async -> Bool {
        // v1: every Pro entitlement unlocks together. Future tiers can
        // switch on `entitlement` here.
        _ = entitlement
        return currentStatus.isPro
    }

    public func availableProducts() async throws -> [SubscriptionProduct] {
        products
    }

    @discardableResult
    public func purchase(productID: SubscriptionProduct.ID) async throws -> SubscriptionStatus {
        guard let product = products.first(where: { $0.id == productID }) else {
            throw SubscriptionError.productNotFound
        }
        let pro = SubscriptionStatus.Pro(
            plan: product.plan,
            renewalDate: Self.simulatedRenewalDate(for: product.plan),
            isInTrial: product.introductoryOffer != nil,
            source: .appStore
        )
        let newStatus = SubscriptionStatus.pro(pro)
        publish(newStatus)
        return newStatus
    }

    @discardableResult
    public func restorePurchases() async throws -> SubscriptionStatus {
        // No persistent receipts in memory — restore is a no-op and just
        // re-emits the current status so callers can react uniformly.
        publish(currentStatus)
        return currentStatus
    }

    @discardableResult
    public func redeem(code: String) async throws -> SubscriptionStatus {
        let normalised = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard validRedeemCodes.contains(normalised) else {
            throw SubscriptionError.redeemCodeInvalid
        }
        guard !consumedRedeemCodes.contains(normalised) else {
            throw SubscriptionError.redeemCodeAlreadyUsed
        }
        consumedRedeemCodes.insert(normalised)
        let pro = SubscriptionStatus.Pro(
            plan: .yearly,
            renewalDate: Self.simulatedRenewalDate(for: .yearly),
            isInTrial: false,
            source: .redeemCode(normalised)
        )
        let newStatus = SubscriptionStatus.pro(pro)
        publish(newStatus)
        return newStatus
    }

    public func refresh() async {
        publish(currentStatus)
    }

    public func latestSignedTransaction() async -> String? {
        // No StoreKit involvement; the hosted AI path won't authenticate
        // via this service — InMemory is for paywall plumbing only.
        nil
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        throw SubscriptionError.unimplemented
    }

    /// Test/debug hook. Forces a status without going through a purchase
    /// path; used by `MockSubscriptionService` and the in-app dev toggle.
    public func setStatus(_ status: SubscriptionStatus) {
        publish(status)
    }

    // MARK: - Private

    private func register(id: UUID, continuation: AsyncStream<SubscriptionStatus>.Continuation) {
        continuations[id] = continuation
        // Replay current value so subscribers don't have to wait for the
        // next mutation to render their first frame.
        continuation.yield(currentStatus)
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func publish(_ status: SubscriptionStatus) {
        currentStatus = status
        for continuation in continuations.values {
            continuation.yield(status)
        }
    }

    private static func simulatedRenewalDate(for plan: SubscriptionPlan) -> Date {
        let component: Calendar.Component
        switch plan {
        case .monthly: component = .month
        case .yearly: component = .year
        }
        return Calendar.current.date(byAdding: component, value: 1, to: Date()) ?? Date()
    }
}

public extension InMemorySubscriptionService {
    /// Canonical Mira Pro catalog used by the paywall in Phase 1. Real
    /// pricing strings come from StoreKit in Phase 2.
    static let defaultProducts: [SubscriptionProduct] = [
        SubscriptionProduct(
            id: SubscriptionPlan.monthly.appStoreProductID,
            plan: .monthly,
            displayName: String(localized: "Mira Pro — Monthly"),
            displayPrice: "$5.99",
            currencyCode: "USD",
            introductoryOffer: SubscriptionProduct.IntroductoryOffer(kind: .freeTrial(days: 7))
        ),
        SubscriptionProduct(
            id: SubscriptionPlan.yearly.appStoreProductID,
            plan: .yearly,
            displayName: String(localized: "Mira Pro — Yearly"),
            displayPrice: "$49.99",
            currencyCode: "USD",
            introductoryOffer: SubscriptionProduct.IntroductoryOffer(kind: .freeTrial(days: 7))
        ),
    ]
}
