import Foundation

/// App-level surface for raising the paywall from anywhere in the feature
/// tree. Lives here (not in `Features/Paywall`) so feature modules can ask
/// for an upgrade without ever importing each other — a hard project rule.
///
/// The App layer owns the concrete implementation and presents
/// `PaywallView` from its root via `.sheet`. Features simply call
/// `present(_:)` and forget.
public protocol PaywallPresenter: Sendable {
    /// Raises the paywall in the app's root, replacing any context that
    /// was already showing. Idempotent if the user is already Pro — the
    /// implementation may short-circuit.
    ///
    /// `@MainActor` lives on the method, not the protocol, so conforming
    /// types can be value types (e.g. the no-op default) and so the
    /// `EnvironmentKey.defaultValue` initialiser stays nonisolated.
    @MainActor func present(_ context: PaywallContext)

    /// Currently raised paywall context, observed by the
    /// `attachPaywall()` view modifier so that any view in the tree —
    /// including content already inside another sheet — can host the
    /// paywall sheet itself. Necessary because iOS won't stack a
    /// fresh root sheet on top of an existing one.
    @MainActor var pendingContext: PaywallContext? { get }

    /// Clears any active paywall context. Called by `attachPaywall()`'s
    /// sheet binding when SwiftUI dismisses the sheet (swipe-down or
    /// the close button) so the presenter and SwiftUI stay in sync.
    @MainActor func dismiss()
}
