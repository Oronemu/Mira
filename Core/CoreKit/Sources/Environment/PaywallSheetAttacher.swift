import SwiftUI

/// Closure injected by the App composition root that knows how to build
/// `PaywallView` for a given context. Lives in the environment so the
/// shared `attachPaywall()` view modifier — which sits in CoreKit and
/// therefore can't import `FeaturePaywall` — can still render the
/// real paywall view. App injects:
///
/// ```swift
/// .environment(\.paywallViewBuilder) { context in
///     AnyView(PaywallView(context: context))
/// }
/// ```
///
/// Default returns `EmptyView()` so previews and non-app hosts that
/// never inject a builder simply do nothing on `present(_:)`.
public typealias PaywallViewBuilder = @MainActor (PaywallContext) -> AnyView

private struct PaywallViewBuilderKey: EnvironmentKey {
    /// `nonisolated(unsafe)` because EnvironmentKey requires a static
    /// `defaultValue` initialised at module-load time, but the closure
    /// type itself is `@MainActor`. The closure body never runs at
    /// load time — only when SwiftUI invokes it from a view's body,
    /// which is always main-actor. Safe in practice.
    nonisolated(unsafe) static let defaultValue: PaywallViewBuilder = { _ in AnyView(EmptyView()) }
}

public extension EnvironmentValues {
    var paywallViewBuilder: PaywallViewBuilder {
        get { self[PaywallViewBuilderKey.self] }
        set { self[PaywallViewBuilderKey.self] = newValue }
    }
}

/// Mounts a paywall sheet that listens to `paywallPresenter.pendingContext`.
/// Apply on every view that may need to host the paywall — at minimum the
/// app root, plus any sheet whose own buttons can call `present(_:)` (so
/// the paywall lands *on top* of that sheet rather than getting trapped
/// behind it).
private struct AttachPaywallModifier: ViewModifier {
    @Environment(\.paywallPresenter) private var presenter
    @Environment(\.paywallViewBuilder) private var builder

    func body(content: Content) -> some View {
        content
            .sheet(item: pendingBinding) { context in
                builder(context)
            }
    }

    private var pendingBinding: Binding<PaywallContext?> {
        Binding(
            get: { presenter.pendingContext },
            set: { newValue in
                if let newValue {
                    presenter.present(newValue)
                } else {
                    presenter.dismiss()
                }
            }
        )
    }
}

public extension View {
    /// Attaches a paywall sheet at this point in the view hierarchy.
    /// iOS doesn't stack a fresh root sheet over an open one — apply
    /// this modifier inside any sheet that triggers paywall calls so
    /// the paywall renders nested above it.
    func attachPaywall() -> some View {
        modifier(AttachPaywallModifier())
    }
}
