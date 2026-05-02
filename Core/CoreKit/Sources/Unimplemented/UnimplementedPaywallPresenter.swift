import Foundation

/// No-op `PaywallPresenter` used as the environment default. Production
/// callers receive `AppPaywallPresenter` from the App composition root;
/// previews and tests get this fallback so they don't accidentally trigger
/// real sheet presentation.
@MainActor
public final class UnimplementedPaywallPresenter: PaywallPresenter {
    public init() {}
    public func present(_ context: PaywallContext) {}
}
