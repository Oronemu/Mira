import SwiftUI
import CoreKit
import DesignSystem

/// Full-screen paywall presented as a sheet. Shows the contextual hero,
/// the Pro benefit list, the two SKUs, and the primary "Start Free Trial"
/// CTA. Footer bundles the Apple-mandated disclosure plus secondary actions
/// (Restore, Redeem, Privacy, Terms).
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.openURL) private var openURL

    private let context: PaywallContext
    @State private var state: PaywallState?
    @State private var showingRedeem = false

    public init(context: PaywallContext = .general) {
        self.context = context
    }

    public var body: some View {
        Group {
            if let state {
                content(state: state)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if state == nil {
                state = PaywallState(
                    context: context,
                    subscriptionService: subscriptionService
                )
            }
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

    private func content(state: PaywallState) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                hero
                benefits
                productList(state: state)
                purchaseCTA(state: state)
                if let message = state.errorMessage {
                    Text(message)
                        .font(MiraTypography.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                footer(state: state)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topTrailing) { closeButton }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(context.headline)
                .font(MiraTypography.title)
                .multilineTextAlignment(.center)

            Text(context.subheadline)
                .font(MiraTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProBenefitRow(
                icon: "bubble.left.and.bubble.right",
                title: String(localized: "Ask Mira and reflections"),
                subtitle: String(localized: "Hosted by Mira — no API keys to manage.")
            )
            ProBenefitRow(
                icon: "chart.line.uptrend.xyaxis",
                title: String(localized: "Advanced stats"),
                subtitle: String(localized: "Tag correlations, predictions, year-in-review.")
            )
            ProBenefitRow(
                icon: "paintpalette",
                title: String(localized: "Themes and app icons"),
                subtitle: String(localized: "Make Mira look the way you journal.")
            )
            ProBenefitRow(
                icon: "doc.richtext",
                title: String(localized: "PDF templates and importers"),
                subtitle: String(localized: "Export beautifully, import from Day One and Notes.")
            )
            ProBenefitRow(
                icon: "rectangle.stack",
                title: String(localized: "More widgets and smart filters"),
                subtitle: String(localized: "Lock Screen widgets, collections, goals.")
            )
        }
    }

    private func productList(state: PaywallState) -> some View {
        VStack(spacing: 12) {
            if state.isLoading {
                ProgressView().frame(height: 80)
            } else {
                ForEach(state.products) { product in
                    PaywallProductCard(
                        product: product,
                        isSelected: state.selectedProductID == product.id,
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
    }

    private func footer(state: PaywallState) -> some View {
        VStack(spacing: 12) {
            Text(disclosure(for: state))
                .font(MiraTypography.caption)
                .foregroundStyle(.secondary)
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
            .foregroundStyle(.tint)
        }
        .padding(.top, 8)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
                .foregroundStyle(.primary)
        }
        .padding(.top, 12)
        .padding(.trailing, 12)
        .accessibilityLabel(String(localized: "Close"))
    }

    // MARK: - Helpers

    private func badge(for product: SubscriptionProduct, in catalog: [SubscriptionProduct]) -> String? {
        guard product.plan == .yearly else { return nil }
        guard catalog.contains(where: { $0.plan == .monthly }) else { return nil }
        return String(localized: "Save 30%")
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
