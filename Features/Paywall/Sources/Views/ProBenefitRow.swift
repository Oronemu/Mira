import SwiftUI
import DesignSystem

/// Single benefit row on the paywall — SF Symbol + title + supporting copy.
/// Sized for stacking inside a `LazyVStack` so the paywall scrolls smoothly
/// at any Dynamic Type setting.
struct ProBenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MiraTypography.headline)
                Text(subtitle)
                    .font(MiraTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
