import Foundation
import StoreKit
import UIKit
import CoreKit
import Utilities

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
/// Custom redeem codes bypass StoreKit entirely — `redeem(code:)` calls
/// the Cloudflare Worker (`POST /v1/redeem`), which validates the code
/// and writes a synthetic Pro entitlement keyed on the device's vendor
/// identifier. The device ID is persisted in Keychain so subsequent
/// AI and usage calls can authenticate via `redeemUserId`.
public actor StoreKitSubscriptionService: SubscriptionService {
    public typealias ProductIDs = (monthly: String, yearly: String)

    private let productIDs: Set<String>
    private let productOrder: [String]

    private let keychain: KeychainStore
    private static let redeemUserIDKey = "redeem_user_id"
    private static let redeemCodeKey = "redeem_code"

    private var loadedProducts: [String: Product] = [:]
    private var currentStatus: CoreKit.SubscriptionStatus = .unknown
    private var continuations: [UUID: AsyncStream<CoreKit.SubscriptionStatus>.Continuation] = [:]
    private var transactionListener: Task<Void, Never>?

    /// - Parameter productIDs: ordered (monthly, yearly) identifiers
    ///   matching App Store Connect / Mira.storekit. Defaults to the
    ///   canonical `SubscriptionPlan.appStoreProductID` mapping.
    public init(
        productIDs: ProductIDs = (
            monthly: SubscriptionPlan.monthly.appStoreProductID,
            yearly: SubscriptionPlan.yearly.appStoreProductID
        ),
        keychain: KeychainStore = KeychainStore()
    ) {
        self.productIDs = [productIDs.monthly, productIDs.yearly]
        self.productOrder = [productIDs.monthly, productIDs.yearly]
        self.keychain = keychain
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
        let deviceID = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let url = MiraBackendURL.resolve().appendingPathComponent("v1/redeem")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["code": code.trimmingCharacters(in: .whitespacesAndNewlines), "deviceID": deviceID]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SubscriptionError.networkUnavailable
        }
        guard let http = response as? HTTPURLResponse else {
            throw SubscriptionError.backendUnavailable
        }
        switch http.statusCode {
        case 200:
            break
        case 404:
            throw SubscriptionError.redeemCodeInvalid
        case 409:
            throw SubscriptionError.redeemCodeAlreadyUsed
        case 429:
            throw SubscriptionError.networkUnavailable
        default:
            throw SubscriptionError.backendUnavailable
        }

        let dto = try JSONDecoder().decode(RedeemResponseDTO.self, from: data)
        try await keychain.setString(deviceID, for: Self.redeemUserIDKey)
        try await keychain.setString(code, for: Self.redeemCodeKey)

        let renewalDate: Date? = dto.renewalDate.flatMap { Self.iso8601.date(from: $0) }
        let newStatus: CoreKit.SubscriptionStatus = .pro(.init(
            plan: .yearly,
            renewalDate: renewalDate,
            isInTrial: false,
            source: .redeemCode(code)
        ))
        publish(newStatus)
        return newStatus
    }

    public var redeemUserID: String? {
        get async { try? await keychain.string(for: Self.redeemUserIDKey) }
    }

    public func refresh() async {
        let storeKit = await currentEntitlement()
        if storeKit.isPro {
            publish(storeKit)
            return
        }

        // StoreKit has no entitlement. Fall back to a custom redeem grant
        // — but re-validate it against the backend instead of trusting
        // the local Keychain blindly. Keychain survives app reinstall, so
        // a self-grant from its mere presence would make a revoked or
        // expired grant impossible to turn off. We treat the server as
        // the source of truth and clear the Keychain when it disagrees.
        guard let code = try? await keychain.string(for: Self.redeemCodeKey),
              let userID = await redeemUserID else {
            publish(storeKit) // .free or .unknown
            return
        }

        switch await validateRedeem(userID: userID) {
        case .active(let status):
            publish(status)
        case .revoked:
            try? await clearRedeemGrant()
            publish(storeKit)
        case .indeterminate:
            // Transient network/backend failure — keep the last-known
            // grant so legitimate offline users aren't locked out. The
            // next online refresh re-checks and revokes if needed.
            publish(.pro(.init(plan: .yearly, renewalDate: nil, isInTrial: false, source: .redeemCode(code))))
        }
    }

    private enum RedeemValidation {
        case active(CoreKit.SubscriptionStatus)
        case revoked
        case indeterminate
    }

    /// Asks the backend whether a stored redeem grant is still valid.
    /// `.revoked` means the server authoritatively downgraded the user
    /// (unknown id, deleted KV entry, or past `renewalDate`); the caller
    /// should purge the local grant. `.indeterminate` means we couldn't
    /// reach a verdict (network/backend error) and should preserve state.
    private func validateRedeem(userID: String) async -> RedeemValidation {
        let url = MiraBackendURL.resolve().appendingPathComponent("v1/entitlements/redeem")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["redeemUserId": userID])
        } catch {
            return .indeterminate
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .indeterminate
        }
        guard let http = response as? HTTPURLResponse else { return .indeterminate }
        guard http.statusCode == 200 else {
            // 4xx here means a malformed request we won't recover from by
            // retrying, but it isn't a clean "free" verdict either — leave
            // the grant alone rather than risk locking out a paid user on
            // a server bug. Only an explicit `isPro: false` revokes.
            return .indeterminate
        }
        guard let dto = try? JSONDecoder().decode(EntitlementCheckDTO.self, from: data) else {
            return .indeterminate
        }
        guard dto.isPro else { return .revoked }

        let plan: SubscriptionPlan = dto.plan == "monthly" ? .monthly : .yearly
        let renewalDate = dto.renewalDate.flatMap { Self.iso8601.date(from: $0) }
        let code = (try? await keychain.string(for: Self.redeemCodeKey)) ?? ""
        return .active(.pro(.init(
            plan: plan,
            renewalDate: renewalDate,
            isInTrial: dto.isInTrial ?? false,
            source: .redeemCode(code)
        )))
    }

    /// Purges the device-bound redeem credentials. Called when the
    /// backend revokes a grant so the next launch starts clean instead of
    /// resurrecting Pro from a stale Keychain item (which survives
    /// reinstall).
    private func clearRedeemGrant() async throws {
        try await keychain.remove(Self.redeemCodeKey)
        try await keychain.remove(Self.redeemUserIDKey)
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

    public func fetchUsage() async throws -> CoreKit.UsageSnapshot {
        let payload: [String: String]
        if let jws = await latestSignedTransaction() {
            payload = ["signedTransaction": jws]
        } else if let rid = await redeemUserID {
            payload = ["redeemUserId": rid]
        } else {
            throw SubscriptionError.verificationFailed
        }
        let url = MiraBackendURL.resolve().appendingPathComponent("v1/usage")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SubscriptionError.networkUnavailable
        }
        guard let http = response as? HTTPURLResponse else {
            throw SubscriptionError.backendUnavailable
        }
        switch http.statusCode {
        case 200:
            return try Self.snapshot(from: data)
        case 400, 401, 402, 403:
            throw SubscriptionError.verificationFailed
        default:
            throw SubscriptionError.backendUnavailable
        }
    }

    private static func snapshot(from data: Data) throws -> CoreKit.UsageSnapshot {
        let dto: UsageWireDTO
        do {
            dto = try JSONDecoder().decode(UsageWireDTO.self, from: data)
        } catch {
            throw SubscriptionError.backendUnavailable
        }
        guard let periodEnd = Self.iso8601.date(from: dto.periodEnd) else {
            throw SubscriptionError.backendUnavailable
        }
        return CoreKit.UsageSnapshot(
            period: dto.period,
            periodEnd: periodEnd,
            askMira: CoreKit.UsageSnapshot.Dimension(
                used: dto.askMira.used,
                limit: dto.askMira.limit,
                remaining: dto.askMira.remaining
            ),
            manualReflections: CoreKit.UsageSnapshot.Dimension(
                used: dto.manualReflections.used,
                limit: dto.manualReflections.limit,
                remaining: dto.manualReflections.remaining
            )
        )
    }

    private struct RedeemResponseDTO: Decodable, Sendable {
        let isPro: Bool
        let plan: String
        let renewalDate: String?
        let isInTrial: Bool
    }

    /// Response of `POST /v1/entitlements/redeem`. Unlike the redeem DTO
    /// this can describe a downgraded (`isPro: false`) grant, so `plan`,
    /// `renewalDate` and `isInTrial` are all optional.
    private struct EntitlementCheckDTO: Decodable, Sendable {
        let isPro: Bool
        let plan: String?
        let renewalDate: String?
        let isInTrial: Bool?
    }

    private struct UsageWireDTO: Decodable, Sendable {
        struct Dimension: Decodable, Sendable {
            let used: Int
            let limit: Int
            let remaining: Int
        }
        let period: String
        let periodEnd: String
        let askMira: Dimension
        let manualReflections: Dimension
    }

    /// Worker emits ISO8601 with fractional seconds (`.999Z`); the
    /// default `JSONDecoder.iso8601` strategy doesn't handle them, so we
    /// parse periodEnd manually with both options enabled.
    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

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
            price: product.price,
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
