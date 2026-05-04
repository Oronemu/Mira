import SwiftUI
import CoreKit
import DesignSystem

/// Selectable card for a single subscription SKU. The yearly plan is rendered
/// as the *featured* card — taller, with a soft gold gradient surround and a
/// floating "Best value" badge — to make the pricing decision visually
/// pre-loaded toward the better-margin SKU without crowding the screen.
struct PaywallProductCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let isFeatured: Bool
    let savingsBadge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                cardBody
            }
            .overlay(alignment: .top) {
                if let badge = savingsBadge, isFeatured {
                    badgeView(text: badge)
                        .offset(y: -10)
                }
            }
            .padding(.top, isFeatured && savingsBadge != nil ? 10 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var cardBody: some View {
        HStack(alignment: .center, spacing: 16) {
            selectionIndicator

            VStack(alignment: .leading, spacing: 4) {
                Text(planTitle)
                    .font(MiraTypography.headline)
                    .foregroundStyle(MiraPalette.primaryText)

                if let trial = trialCopy {
                    Text(trial)
                        .font(MiraTypography.caption)
                        .foregroundStyle(MiraPalette.secondaryText)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(product.displayPrice)
                    .font(MiraTypography.headline)
                    .foregroundStyle(MiraPalette.primaryText)
                Text(perPeriodCopy)
                    .font(MiraTypography.caption)
                    .foregroundStyle(MiraPalette.secondaryText)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, isFeatured ? 18 : 14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(fillStyle)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: isSelected ? 2 : 1)
        }
        .shadow(
            color: isFeatured ? MiraPalette.proAccent(.gold).opacity(isSelected ? 0.28 : 0.15) : .black.opacity(0.04),
            radius: isFeatured ? 18 : 6,
            x: 0,
            y: isFeatured ? 10 : 2
        )
        .scaleEffect(isSelected ? 1.0 : 0.985)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: isSelected)
    }

    /// Both cards share the gold accent for selection — yearly stays
     /// visually special by carrying the gold→rose *gradient* + glow,
     /// while monthly uses a softer solid gold tint. This keeps the
     /// paywall on a single coherent palette (no stray system blue).
    private var fillStyle: AnyShapeStyle {
        if isFeatured {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        MiraPalette.proAccent(.gold).opacity(isSelected ? 0.20 : 0.10),
                        MiraPalette.proAccent(.rose).opacity(isSelected ? 0.12 : 0.05),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if isSelected {
            return AnyShapeStyle(MiraPalette.proAccent(.gold).opacity(0.10))
        }
        return AnyShapeStyle(MiraPalette.surfaceElevated.opacity(0.55))
    }

    private var borderStyle: AnyShapeStyle {
        if isSelected {
            if isFeatured {
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [MiraPalette.proAccent(.gold), MiraPalette.proAccent(.rose)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            return AnyShapeStyle(MiraPalette.proAccent(.gold))
        }
        return AnyShapeStyle(MiraPalette.divider)
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? MiraPalette.proAccent(.gold) : MiraPalette.secondaryText.opacity(0.4),
                    lineWidth: 2
                )
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(
                        isFeatured
                            ? AnyShapeStyle(LinearGradient(
                                colors: [MiraPalette.proAccent(.gold), MiraPalette.proAccent(.rose)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(MiraPalette.proAccent(.gold))
                    )
                    .frame(width: 12, height: 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }

    private func badgeView(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [MiraPalette.proAccent(.gold), MiraPalette.proAccent(.rose)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .shadow(color: MiraPalette.proAccent(.gold).opacity(0.4), radius: 8, x: 0, y: 3)
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
