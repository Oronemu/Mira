import Foundation
import CoreKit

/// Configurable `SubscriptionService` for unit tests and SwiftUI previews.
/// Lets each test set up exactly the failure / success it cares about
/// without dragging in the full StoreKit or in-memory implementations.
public actor MockSubscriptionService: SubscriptionService {
    public typealias PurchaseHandler = @Sendable (SubscriptionProduct.ID) async throws -> SubscriptionStatus
    public typealias RestoreHandler = @Sendable () async throws -> SubscriptionStatus
    public typealias RedeemHandler = @Sendable (String) async throws -> SubscriptionStatus

    private var currentStatus: SubscriptionStatus
    private let stubbedProducts: [SubscriptionProduct]
    private var continuations: [UUID: AsyncStream<SubscriptionStatus>.Continuation] = [:]

    public private(set) var purchaseCalls: [SubscriptionProduct.ID] = []
    public private(set) var restoreCallCount: Int = 0
    public private(set) var redeemCalls: [String] = []
    public private(set) var refreshCallCount: Int = 0

    private let purchaseHandler: PurchaseHandler?
    private let restoreHandler: RestoreHandler?
    private let redeemHandler: RedeemHandler?

    public init(
        initialStatus: SubscriptionStatus = .free,
        products: [SubscriptionProduct] = [],
        purchaseHandler: PurchaseHandler? = nil,
        restoreHandler: RestoreHandler? = nil,
        redeemHandler: RedeemHandler? = nil
    ) {
        self.currentStatus = initialStatus
        self.stubbedProducts = products
        self.purchaseHandler = purchaseHandler
        self.restoreHandler = restoreHandler
        self.redeemHandler = redeemHandler
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
        _ = entitlement
        return currentStatus.isPro
    }

    public func availableProducts() async throws -> [SubscriptionProduct] {
        stubbedProducts
    }

    @discardableResult
    public func purchase(productID: SubscriptionProduct.ID) async throws -> SubscriptionStatus {
        purchaseCalls.append(productID)
        if let handler = purchaseHandler {
            let next = try await handler(productID)
            publish(next)
            return next
        }
        return currentStatus
    }

    @discardableResult
    public func restorePurchases() async throws -> SubscriptionStatus {
        restoreCallCount += 1
        if let handler = restoreHandler {
            let next = try await handler()
            publish(next)
            return next
        }
        return currentStatus
    }

    @discardableResult
    public func redeem(code: String) async throws -> SubscriptionStatus {
        redeemCalls.append(code)
        if let handler = redeemHandler {
            let next = try await handler(code)
            publish(next)
            return next
        }
        return currentStatus
    }

    public func refresh() async {
        refreshCallCount += 1
    }

    public func latestSignedTransaction() async -> String? { stubbedSignedTransaction }

    private var stubbedSignedTransaction: String?

    /// Test hook — pre-load the JWS that `latestSignedTransaction()`
    /// will return without paying for a real StoreKit transaction.
    public func setSignedTransaction(_ jws: String?) {
        stubbedSignedTransaction = jws
    }

    /// Test hook — flips the status without running through a purchase
    /// path. Useful for setting up "user is already Pro" preconditions.
    public func setStatus(_ status: SubscriptionStatus) {
        publish(status)
    }

    // MARK: - Private

    private func register(id: UUID, continuation: AsyncStream<SubscriptionStatus>.Continuation) {
        continuations[id] = continuation
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
}
