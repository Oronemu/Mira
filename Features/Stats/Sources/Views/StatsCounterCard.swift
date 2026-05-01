import SwiftUI
import DesignSystem

/// Small glass card with a serif headline number and quiet subtitle. Used
/// for "14,320 words", "7 reflections", "5 conversations with Mira".
/// Layout is tall (number on top, subtitle below) — fits two or three in
/// a row.
struct StatsCounterCard: View {
    let icon: String
    let value: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let moodLevel: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.mood(level: moodLevel).opacity(0.9))
                Text(title)
                    .eyebrowStyle()
            }

            Text(value)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(MiraPalette.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 5)
    }
}
