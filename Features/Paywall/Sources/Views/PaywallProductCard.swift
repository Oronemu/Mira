import SwiftUI
import CoreKit
import DesignSystem

/// Selectable card for a single subscription SKU. Highlights the yearly
/// plan with a "Best value — save 30%" badge and surfaces the introductory
/// offer (free trial) so the user knows what they get on first purchase.
struct PaywallProductCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let savingsBadge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 16) {
                selectionIndicator

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(planTitle)
                            .font(MiraTypography.headline)
                        if let badge = savingsBadge {
                            Text(badge)
                                .font(MiraTypography.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.tint.opacity(0.15), in: Capsule())
                                .foregroundStyle(.tint)
                        }
                    }
                    if let trial = trialCopy {
                        Text(trial)
                            .font(MiraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(MiraTypography.headline)
                    Text(perPeriodCopy)
                        .font(MiraTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var planTitle: String {
        switch product.plan {
        case .monthly: String(localized: "Monthly")
        case .yearly: String(localized: "Yearly")
        }
    }

    private var perPeriodCopy: String {
        switch product.plan {
        case .monthly: String(localized: "per month")
        case .yearly: String(localized: "per year")
        }
    }

    private var trialCopy: String? {
        guard let offer = product.introductoryOffer else { return nil }
        switch offer.kind {
        case .freeTrial(let days):
            return String(format: String(localized: "First %d days free"), days)
        case .payAsYouGo(let price, let periods):
            return String(format: String(localized: "%@ for %d periods, then full price"), price, periods)
        case .payUpFront(let price):
            return String(format: String(localized: "%@ upfront, then full price"), price)
        }
    }
}
