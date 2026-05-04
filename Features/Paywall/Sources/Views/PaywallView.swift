import SwiftUI
import CoreKit
import DesignSystem

/// Full-screen paywall presented as a sheet. The redesign leans into the
/// app's "stoic editorial" register: a warm AmbientBackground in mood
/// levels 4–5 (terracotta + sage) under a sparkle constellation, serif
/// hero title, glass-tinted benefit rows, a featured yearly plan with
/// "Best value" badge, and a cascade fade-in when the sheet first opens.
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.openURL) private var openURL

    private let context: PaywallContext
    @State private var state: PaywallState?
    @State private var showingRedeem = false
    @State private var hasAppeared = false

    public init(context: PaywallContext = .general) {
        self.context = context
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [4, 5], intensity: 0.65)

            Group {
                if let state {
                    content(state: state)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            if state == nil {
                state = PaywallState(
                    context: context,
                    subscriptionService: subscriptionService
                )
            }
            // Stagger after the first frame so the cascade plays *during*
            // the sheet's own present transition, not before it lands.
            try? await Task.sleep(for: .milliseconds(80))
            hasAppeared = true
            await state?.load()
        }
        .onChange(of: state?.didUnlockPro ?? false) { _, unlocked in
            if unlocked { dismiss() }
        }
        .sheet(isPresented: $showingRedeem) {
            if let state {
                RedeemCodeView(state: state)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Content

    /// Each direct child uses `.scrollTransition` so it fades + lifts as
     /// it scrolls into view. Combined with the initial `hasAppeared`
     /// fade-in this gives a single coherent rule: nothing appears unless
     /// it's actually on screen.
    private func content(state: PaywallState) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                    .firstAppearFade()

                benefits

                productList(state: state)
                    .firstAppearFade()

                purchaseCTA(state: state)
                    .firstAppearFade()

                if let message = state.errorMessage {
                    Text(message)
                        .font(MiraTypography.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                footer(state: state)
                    .firstAppearFade()
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 32)
            .opacity(hasAppeared ? 1 : 0)
            .animation(.easeOut(duration: 0.45), value: hasAppeared)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topTrailing) { closeButton }
    }

    // MARK: - Sections

    private var hero: some View {
        // Eyebrow shown only for feature-specific contexts so it doesn't
        // duplicate the headline on the generic ".general" case (where the
        // headline already reads "Mira Pro").
        VStack(spacing: 16) {
            PaywallHeroIcon()

            if case .feature = context {
                Text(String(localized: "Mira Pro"))
                    .eyebrowStyle(color: MiraPalette.proAccent(.gold))
            }

            Text(context.headline)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .minimumScaleFactor(0.78)
                .lineLimit(3)

            Text(context.subheadline)
                .font(.system(.body, design: .serif))
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
    }

    /// Mirrors `ProEntitlement` 1:1 so that adding a Pro capability stays
     /// a single-source change. Subtitle copy stays terse — the row is one
     /// of nine, not the full marketing pitch.
    private var benefits: some View {
        VStack(spacing: 10) {
            ProBenefitRow(
                icon: "bubble.left.and.bubble.right",
                moodLevel: 5,
                title: String(localized: "Ask Mira"),
                subtitle: String(localized: "Hosted conversations and weekly reflections.")
            )
            .firstAppearFade()
            ProBenefitRow(
                icon: "person.bubble",
                moodLevel: 4,
                title: String(localized: "Custom AI personas"),
                subtitle: String(localized: "Author the system prompt that shapes Mira's voice.")
            )
            .firstAppearFade()
            ProBenefitRow(
                icon: "chart.line.uptrend.xyaxis",
                moodLevel: 5,
                title: String(localized: "Advanced stats"),
                subtitle: String(localized: "Tag correlations, predictions, year-in-review.")
            )
            .firstAppearFade()
            ProBenefitRow(
                icon: "target",
                moodLevel: 4,
                title: String(localized: "Goals and habits"),
                subtitle: String(localized: "Tag-driven habits and goals alongside your journal.")
            )
            .firstAppearFade()
            ProBenefitRow(
                icon: "line.3.horizontal.decrease.circle",
                moodLevel: 3,
                title: String(localized: "Smart filters"),
                subtitle: String(localized: "Save the filters you keep coming back to.")
            )
            .firstAppearFade()
            ProBenefitRow(
                icon: "paintpalette",
                moodLevel: 2,
                title: String(localized: "Themes and app icons"),
                subtitle: String(localized: "Make Mira look the way you journal.")
            )
            .firstAppearFade()
            ProBenefitRow(
                icon: "doc.richtext",
                moodLevel: 3,
                title: String(localized: "PDF export with templates"),
                subtitle: String(localized: "Print, share, archive — beautifully laid out.")
            )
            .firstAppearFade()
            ProBenefitRow(
                icon: "rectangle.stack",
                moodLevel: 2,
                title: String(localized: "Lock Screen widgets"),
                subtitle: String(localized: "Plus more Home Screen widget sizes.")
            )
            .firstAppearFade()
            ProBenefitRow(
                icon: "square.and.arrow.down",
                moodLevel: 1,
                title: String(localized: "Importers"),
                subtitle: String(localized: "Bring entries from Day One, Apple Notes, Markdown.")
            )
            .firstAppearFade()
        }
    }

    private func productList(state: PaywallState) -> some View {
        VStack(spacing: 14) {
            if state.isLoading {
                ProgressView().frame(height: 80)
            } else {
                ForEach(state.products) { product in
                    PaywallProductCard(
                        product: product,
                        isSelected: state.selectedProductID == product.id,
                        isFeatured: product.plan == .yearly,
                        savingsBadge: badge(for: product, in: state.products),
                        onTap: { state.selectProduct(product.id) }
                    )
                }
            }
        }
    }

    private func purchaseCTA(state: PaywallState) -> some View {
        let title = state.products.first(where: { $0.id == state.selectedProductID })?.introductoryOffer != nil
            ? String(localized: "Start 7-Day Free Trial")
            : String(localized: "Continue")
        return PrimaryButton(title, isLoading: state.isPurchasing) {
            Task { await state.purchaseSelected() }
        }
        .disabled(state.selectedProductID == nil)
        .shadow(color: MiraPalette.proAccent(.gold).opacity(0.25), radius: 16, x: 0, y: 6)
    }

    private func footer(state: PaywallState) -> some View {
        VStack(spacing: 14) {
            Text(disclosure(for: state))
                .font(MiraTypography.caption)
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Button(String(localized: "Restore")) {
                    Task { await state.restorePurchases() }
                }
                .disabled(state.isRestoring)

                Button(String(localized: "Redeem code")) {
                    state.clearError()
                    showingRedeem = true
                }

                Button(String(localized: "Privacy")) {
                    if let url = URL(string: "https://mira.app/privacy") { openURL(url) }
                }

                Button(String(localized: "Terms")) {
                    if let url = URL(string: "https://mira.app/terms") { openURL(url) }
                }
            }
            .font(MiraTypography.caption)
            .foregroundStyle(MiraPalette.secondaryText)
        }
        .padding(.top, 4)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
                .foregroundStyle(MiraPalette.primaryText)
        }
        .padding(.top, 12)
        .padding(.trailing, 16)
        .accessibilityLabel(String(localized: "Close"))
    }

    // MARK: - Helpers

    /// Computes the savings on yearly vs paying monthly for 12 months,
    /// rounded to a whole percent so the badge never shows "30.45%".
    /// Falls back to a no-percentage "Best value" if either side lacks
    /// a raw price (e.g. test catalogs that only set `displayPrice`).
    private func badge(for product: SubscriptionProduct, in catalog: [SubscriptionProduct]) -> String? {
        guard product.plan == .yearly else { return nil }
        guard let monthly = catalog.first(where: { $0.plan == .monthly }) else { return nil }

        if let monthlyPrice = monthly.price, let yearlyPrice = product.price, monthlyPrice > 0 {
            let twelveMonths = monthlyPrice * 12
            let saved = twelveMonths - yearlyPrice
            guard saved > 0 else { return String(localized: "Best value") }
            let percent = NSDecimalNumber(decimal: saved / twelveMonths * 100).intValue
            return String(format: String(localized: "Best value · save %d%%"), percent)
        }
        return String(localized: "Best value")
    }

    private func disclosure(for state: PaywallState) -> String {
        guard let selected = state.products.first(where: { $0.id == state.selectedProductID }) else {
            return String(localized: "Subscription auto-renews until cancelled in App Store settings.")
        }
        switch selected.plan {
        case .monthly:
            return String(format: String(localized: "%@ per month after the free trial. Renews automatically until cancelled in App Store settings."), selected.displayPrice)
        case .yearly:
            return String(format: String(localized: "%@ per year after the free trial. Renews automatically until cancelled in App Store settings."), selected.displayPrice)
        }
    }
}

private extension View {
    /// Fades + lifts the view the *first* time it enters the view tree
    /// (driven by .onAppear, one-shot). Re-scrolling past it doesn't
    /// re-trigger the animation — the cascade plays once and stays put.
    func firstAppearFade() -> some View {
        modifier(FirstAppearFadeModifier())
    }
}

/// Per-instance @State means each row tracks its own first-appear flag,
/// so each one fires the spring exactly once as it enters the viewport
/// (lazy stack) or on initial render (eager stack). Subsequent re-renders
/// keep `visible == true`, which makes `.opacity` and `.offset` no-ops.
private struct FirstAppearFadeModifier: ViewModifier {
    @State private var visible: Bool = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear {
                guard !visible else { return }
                withAnimation(.spring(duration: 0.55, bounce: 0.18)) {
                    visible = true
                }
            }
    }
}
