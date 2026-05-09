import Foundation
import Observation
import CoreKit

/// State container for `PaywallView`. Holds the catalogue, selection, and
/// the in-flight purchase / restore / redeem flags. Lives on the main actor
/// because every property feeds SwiftUI directly.
///
/// The paywall is intentionally context-aware — its headline and analytics
/// vary depending on whether it was opened from the Settings banner, an
/// AskMira gate, or the manual Insights trigger. Callers pass a
/// `PaywallContext` at construction time; the state is otherwise identical.
@MainActor
@Observable
public final class PaywallState {
    public let context: PaywallContext

    public private(set) var products: [SubscriptionProduct] = []
    public private(set) var status: SubscriptionStatus = .unknown
    public private(set) var isLoading: Bool = true
    public private(set) var isPurchasing: Bool = false
    public private(set) var isRestoring: Bool = false
    public private(set) var isRedeeming: Bool = false
    public private(set) var errorMessage: String?

    /// Currently highlighted SKU. Defaults to the yearly plan since it's
    /// the better-value option Mira wants to nudge users toward.
    public var selectedProductID: SubscriptionProduct.ID?

    /// `true` once a purchase / restore / redeem has flipped the status to
    /// `.pro`. Views observe this to dismiss themselves.
    public var didUnlockPro: Bool { status.isPro }

    private let subscriptionService: any SubscriptionService
    private var statusObservation: Task<Void, Never>?

    public init(
        context: PaywallContext,
        subscriptionService: any SubscriptionService
    ) {
        self.context = context
        self.subscriptionService = subscriptionService
    }

    isolated deinit {
        statusObservation?.cancel()
    }

    /// Loads the product list and starts observing entitlement changes.
    /// Safe to call multiple times — callers typically invoke it from a
    /// view's `.task`, which SwiftUI already debounces by lifetime.
    public func load() async {
        if statusObservation == nil {
            let stream = subscriptionService.statusUpdates
            statusObservation = Task { [weak self] in
                for await snapshot in stream {
                    await MainActor.run { self?.status = snapshot }
                }
            }
        }
        await refreshStatus()
        await fetchProducts()
    }

    public func selectProduct(_ id: SubscriptionProduct.ID) {
        selectedProductID = id
    }

    /// Clears any pending error banner. Useful when the user takes a fresh
    /// action (e.g. tapping "Redeem code" after a failed purchase) so the
    /// stale message doesn't bleed into the next flow.
    public func clearError() {
        errorMessage = nil
    }

    public func purchaseSelected() async {
        guard let id = selectedProductID, !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            _ = try await subscriptionService.purchase(productID: id)
        } catch SubscriptionError.userCancelled {
            // Silent — user explicitly dismissed the StoreKit sheet.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }
        do {
            _ = try await subscriptionService.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func redeem(code: String) async {
        guard !isRedeeming else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "Enter a code to continue.")
            return
        }
        isRedeeming = true
        errorMessage = nil
        defer { isRedeeming = false }
        do {
            _ = try await subscriptionService.redeem(code: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await subscriptionService.availableProducts()
            products = fetched
            if fetched.isEmpty {
                // StoreKit returned an empty catalog without throwing —
                // typically means the Paid Apps Agreement isn't active,
                // the IAPs aren't attached to this build, or App Store
                // Connect can't reach the device. Surface a message so
                // the screen isn't silently empty.
                errorMessage = String(localized: "Subscriptions are unavailable right now. Please try again later.")
                return
            }
            if selectedProductID == nil {
                // Default to yearly because it's the "save 30%" SKU.
                selectedProductID = fetched.first(where: { $0.plan == .yearly })?.id
                    ?? fetched.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshStatus() async {
        status = await subscriptionService.status
    }
}
