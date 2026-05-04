import SwiftUI
import DesignSystem

/// Single benefit row on the paywall. Icon sits inside a soft mood-tinted
/// disc to lift it off the surface and tie the row visually to the rest of
/// the journal. Title uses headline weight; supporting copy drops into the
/// editorial serif body so the paywall reads more like a chapter than a
/// product comparison.
struct ProBenefitRow: View {
    let icon: String
    let moodLevel: Int
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(MiraPalette.mood(level: moodLevel).opacity(0.22))
                Circle()
                    .strokeBorder(MiraPalette.mood(level: moodLevel).opacity(0.35), lineWidth: 0.5)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MiraPalette.mood(level: moodLevel))
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText)
                Text(subtitle)
                    .font(.system(size: 13.5, design: .serif))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MiraPalette.surfaceElevated.opacity(0.55))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MiraPalette.divider, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}
