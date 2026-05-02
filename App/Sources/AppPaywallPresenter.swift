import Foundation
import Observation
import CoreKit

/// Concrete `PaywallPresenter` used by the live app. Stores the active
/// context as observable state so `RootView` can drive a `.sheet(item:)`
/// off it. Lives at the App layer because only the composition root knows
/// how to mount the paywall in the view hierarchy — feature modules just
/// call `present(_:)`.
@MainActor
@Observable
public final class AppPaywallPresenter: PaywallPresenter {
    public var pendingContext: PaywallContext?

    public init() {}

    public func present(_ context: PaywallContext) {
        pendingContext = context
    }

    public func dismiss() {
        pendingContext = nil
    }
}
