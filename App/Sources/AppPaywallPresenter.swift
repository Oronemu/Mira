import Foundation
import Observation
import CoreKit

/// Concrete `PaywallPresenter` used by the live app. Stores the active
/// context as observable state so `RootView` can drive a `.sheet(item:)`
/// off it. Lives at the App layer because only the composition root knows
/// how to mount the paywall in the view hierarchy — feature modules just
/// call `present(_:)`.
///
/// Analytics is centralised here so every `present(_:)` call site emits
/// a consistent `paywall_presented` event without each feature having
/// to remember to log.
@MainActor
@Observable
public final class AppPaywallPresenter: PaywallPresenter {
    public var pendingContext: PaywallContext?

    private let analyticsService: any AnalyticsService

    public init(analyticsService: any AnalyticsService) {
        self.analyticsService = analyticsService
    }

    public func present(_ context: PaywallContext) {
        analyticsService.log(
            event: "paywall_presented",
            parameters: ["context": .string(context.analyticsName)]
        )
        pendingContext = context
    }

    public func dismiss() {
        pendingContext = nil
    }
}
