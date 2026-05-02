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
}
