import Foundation

/// No-op `PaywallPresenter` used as the environment default. Production
/// callers receive `AppPaywallPresenter` from the App composition root;
/// previews and tests get this fallback so they don't accidentally trigger
/// real sheet presentation.
///
/// Implemented as a `struct` (rather than an `@MainActor` class) so the
/// `EnvironmentKey.defaultValue` static initialiser, which runs on a
/// nonisolated context, can construct it without an actor hop.
public struct UnimplementedPaywallPresenter: PaywallPresenter {
    public init() {}
    @MainActor public func present(_ context: PaywallContext) {}
    @MainActor public func dismiss() {}
    @MainActor public var pendingContext: PaywallContext? { nil }
}
