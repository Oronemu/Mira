import Foundation
import StoreKit
import CoreKit

/// Production `SubscriptionService` backed by StoreKit 2.
///
/// Responsibilities:
/// 1. Fetch the catalogued products (`Product.products(for:)`) when the
///    paywall asks for them.
/// 2. Drive purchases through `Product.purchase()`, verify the resulting
///    `Transaction` JWS on-device, and `finish()` it.
/// 3. Listen to `Transaction.updates` for renewals, refunds, and
///    family-sharing events and re-evaluate the cached status.
/// 4. Materialise the user's current entitlement on launch via
///    `Transaction.currentEntitlements` and on every "Restore Purchases".
///
/// Phase 1's redeem-code flow does not exist in StoreKit — it requires a
/// server. This implementation throws `.unimplemented` for `redeem(code:)`;
/// the App layer can pick a fallback (Apple offer-code sheet via
/// `AppStore.presentOfferCodeRedeemSheet(in:)`, or our future Cloudflare
/// Worker) once the backend is in place.
public actor StoreKitSubscriptionService: SubscriptionService {
    public typealias ProductIDs = (monthly: String, yearly: String)

    private let productIDs: Set<String>
    private let productOrder: [String]

    private var loadedProducts: [String: Product] = [:]
    private var currentStatus: CoreKit.SubscriptionStatus = .unknown
    private var continuations: [UUID: AsyncStream<CoreKit.SubscriptionStatus>.Continuation] = [:]
    private var transactionListener: Task<Void, Never>?

    /// - Parameter productIDs: ordered (monthly, yearly) identifiers
    ///   matching App Store Connect / Mira.storekit. Defaults to the
    ///   canonical `SubscriptionPlan.appStoreProductID` mapping.
    public init(productIDs: ProductIDs = (
        monthly: SubscriptionPlan.monthly.appStoreProductID,
        yearly: SubscriptionPlan.yearly.appStoreProductID
    )) {
        self.productIDs = [productIDs.monthly, productIDs.yearly]
        self.productOrder = [productIDs.monthly, productIDs.yearly]
    }

    /// Spin up the transaction listener and load the user's current
    /// entitlement. Call once from the App composition root after init.
    public func bootstrap() {
        if transactionListener == nil {
            transactionListener = Task { [weak self] in
                for await update in Transaction.updates {
                    await self?.handle(update: update)
                }
            }
        }
        Task { await self.refresh() }
    }

    // MARK: - SubscriptionService

    public var status: CoreKit.SubscriptionStatus { currentStatus }

    public nonisolated var statusUpdates: AsyncStream<CoreKit.SubscriptionStatus> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    public func isEntitled(to entitlement: ProEntitlement) async -> Bool {
        _ = entitlement
        return currentStatus.isPro
    }

    public func availableProducts() async throws -> [SubscriptionProduct] {
        let products = try await loadProductsIfNeeded()
        return productOrder.compactMap { id -> SubscriptionProduct? in
            guard let product = products[id] else { return nil }
            return Self.snapshot(from: product)
        }
    }

    @discardableResult
    public func purchase(productID: SubscriptionProduct.ID) async throws -> CoreKit.SubscriptionStatus {
        let products = try await loadProductsIfNeeded()
        guard let product = products[productID] else {
            throw SubscriptionError.productNotFound
        }

        let purchaseResult: Product.PurchaseResult
        do {
            purchaseResult = try await product.purchase()
        } catch StoreKitError.userCancelled {
            throw SubscriptionError.userCancelled
        } catch StoreKitError.networkError {
            throw SubscriptionError.networkUnavailable
        } catch {
            throw SubscriptionError.purchaseFailed(message: error.localizedDescription)
        }

        switch purchaseResult {
        case .success(let verification):
            let transaction = try Self.verify(verification)
            await transaction.finish()
            await refresh()
            return currentStatus

        case .userCancelled:
            throw SubscriptionError.userCancelled

        case .pending:
            // Awaiting parental approval (Ask to Buy) or other deferred
            // state — Transaction.updates will fire when it resolves.
            return currentStatus

        @unknown default:
            throw SubscriptionError.purchaseFailed(message: "Unknown StoreKit result.")
        }
    }

    @discardableResult
    public func restorePurchases() async throws -> CoreKit.SubscriptionStatus {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            throw SubscriptionError.userCancelled
        } catch StoreKitError.networkError {
            throw SubscriptionError.networkUnavailable
        } catch {
            throw SubscriptionError.purchaseFailed(message: error.localizedDescription)
        }
        await refresh()
        return currentStatus
    }

    @discardableResult
    public func redeem(code: String) async throws -> CoreKit.SubscriptionStatus {
        // StoreKit doesn't expose a programmatic redeem path for our own
        // codes — Apple's offer-code redeem sheet is a UI-level affair.
        // The hosted Cloudflare Worker (Phase 3) will validate Mira-issued
        // codes and flip the entitlement on the server.
        _ = code
        throw SubscriptionError.unimplemented
    }

    public func refresh() async {
        let resolved = await currentEntitlement()
        publish(resolved)
    }

    public func latestSignedTransaction() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            guard transaction.productType == .autoRenewable else { continue }
            if transaction.revocationDate != nil { continue }
            // The JWS lives on the VerificationResult, not on the
            // Transaction value. Re-extract from the result we just
            // pattern-matched.
            return result.jwsRepresentation
        }
        return nil
    }

    // MARK: - Private

    private func loadProductsIfNeeded() async throws -> [String: Product] {
        if !loadedProducts.isEmpty { return loadedProducts }
        do {
            let fetched = try await Product.products(for: Array(productIDs))
            for product in fetched {
                loadedProducts[product.id] = product
            }
            return loadedProducts
        } catch StoreKitError.networkError {
            throw SubscriptionError.networkUnavailable
        } catch {
            throw SubscriptionError.purchaseFailed(message: error.localizedDescription)
        }
    }

    private func handle(update: VerificationResult<Transaction>) async {
        switch update {
        case .verified(let transaction):
            await transaction.finish()
            await refresh()
        case .unverified:
            // Drop unverified updates on the floor — the next valid
            // transaction will arrive when Apple republishes it.
            break
        }
    }

    private static func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw SubscriptionError.verificationFailed
        }
    }

    /// Walks `Transaction.currentEntitlements` for the auto-renewable
    /// subscription that backs Mira Pro and turns it into a domain
    /// `CoreKit.SubscriptionStatus`. If nothing is found the user is `.free`.
    private func currentEntitlement() async -> CoreKit.SubscriptionStatus {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            guard transaction.productType == .autoRenewable else { continue }
            // Revoked / refunded transactions are still surfaced by
            // currentEntitlements until the next sync; explicitly drop
            // them so the UI doesn't think the user is still Pro.
            if transaction.revocationDate != nil { continue }

            let plan: SubscriptionPlan = transaction.productID == SubscriptionPlan.yearly.appStoreProductID
                ? .yearly
                : .monthly

            let isInTrial: Bool = {
                if #available(iOS 17.2, *) {
                    return transaction.offer?.type == .introductory
                }
                return false
            }()

            return .pro(
                .init(
                    plan: plan,
                    renewalDate: transaction.expirationDate,
                    isInTrial: isInTrial,
                    source: .appStore
                )
            )
        }
        return .free
    }

    private func register(id: UUID, continuation: AsyncStream<CoreKit.SubscriptionStatus>.Continuation) {
        continuations[id] = continuation
        continuation.yield(currentStatus)
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func publish(_ status: CoreKit.SubscriptionStatus) {
        currentStatus = status
        for continuation in continuations.values {
            continuation.yield(status)
        }
    }

    // MARK: - Product → SubscriptionProduct mapping

    private static func snapshot(from product: Product) -> SubscriptionProduct {
        let plan: SubscriptionPlan = product.id == SubscriptionPlan.yearly.appStoreProductID
            ? .yearly
            : .monthly

        let intro: SubscriptionProduct.IntroductoryOffer? = {
            guard let offer = product.subscription?.introductoryOffer else { return nil }
            switch offer.paymentMode {
            case .freeTrial:
                let days = approximateDays(in: offer.period)
                return SubscriptionProduct.IntroductoryOffer(kind: .freeTrial(days: days))
            case .payAsYouGo:
                return SubscriptionProduct.IntroductoryOffer(
                    kind: .payAsYouGo(
                        displayPrice: offer.displayPrice,
                        periods: offer.periodCount
                    )
                )
            case .payUpFront:
                return SubscriptionProduct.IntroductoryOffer(
                    kind: .payUpFront(displayPrice: offer.displayPrice)
                )
            default:
                return nil
            }
        }()

        return SubscriptionProduct(
            id: product.id,
            plan: plan,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            currencyCode: product.priceFormatStyle.currencyCode,
            introductoryOffer: intro
        )
    }

    private static func approximateDays(in period: Product.SubscriptionPeriod) -> Int {
        let count = period.value
        switch period.unit {
        case .day: return count
        case .week: return count * 7
        case .month: return count * 30
        case .year: return count * 365
        @unknown default: return count
        }
    }
}
