import SwiftUI
import Utilities
import DesignSystem

/// Three glass capsules side-by-side: how often the user felt good /
/// steady / low across the selected range. Mood color encodes severity
/// (5 = good, 3 = steady, 2 = low) so the row reads as a quiet status bar
/// without needing emoji.
struct StatsMoodCountersRow: View {
    let counters: StatisticsCalculator.MoodCounters

    var body: some View {
        HStack(spacing: 10) {
            cell(
                title: "Good",
                titleComment: "Stats — mood counter label for entries with mood 4-5",
                count: counters.good,
                moodLevel: 5
            )
            cell(
                title: "Average",
                titleComment: "Stats — mood counter label for entries with mood 3",
                count: counters.steady,
                moodLevel: 3
            )
            cell(
                title: "Low",
                titleComment: "Stats — mood counter label for entries with mood 1-2",
                count: counters.low,
                moodLevel: 2
            )
        }
    }

    private func cell(title: String.LocalizationValue, titleComment: StaticString, count: Int, moodLevel: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(MiraPalette.mood(level: moodLevel))
                    .frame(width: 8, height: 8)
                Text(String(localized: title, comment: titleComment))
                    .eyebrowStyle()
            }
            Text("\(count)")
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(MiraPalette.mood(level: moodLevel).opacity(count > 0 ? 0.22 : 0), lineWidth: 1)
        }
    }
}
