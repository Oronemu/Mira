import Foundation

/// Errors thrown by `SubscriptionService` operations. Cases are designed to
/// drive specific UI states on the paywall (cancel buttons, retry banners,
/// invalid-code toasts) rather than carry server-side debug strings.
public enum SubscriptionError: LocalizedError, Sendable {
    case userCancelled
    case productNotFound
    case purchaseFailed(message: String)
    case redeemCodeInvalid
    case redeemCodeAlreadyUsed
    case networkUnavailable
    case backendUnavailable
    case verificationFailed
    case unimplemented

    public var errorDescription: String? {
        switch self {
        case .userCancelled:
            String(localized: "Purchase cancelled.")
        case .productNotFound:
            String(localized: "This subscription is not available right now.")
        case .purchaseFailed(let message):
            message
        case .redeemCodeInvalid:
            String(localized: "This code is not valid.")
        case .redeemCodeAlreadyUsed:
            String(localized: "This code has already been used.")
        case .networkUnavailable:
            String(localized: "No internet connection. Try again when you're back online.")
        case .backendUnavailable:
            String(localized: "Mira's subscription service is temporarily unavailable.")
        case .verificationFailed:
            String(localized: "We couldn't verify your purchase. Try Restore Purchases.")
        case .unimplemented:
            String(localized: "Subscription service is not configured.")
        }
    }
}
