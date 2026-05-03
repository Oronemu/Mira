import SwiftUI
import CoreKit
import Utilities
import DesignSystem

/// Pro card — top tags ranked by entry count, with a mood-tinted bar
/// for each showing how the average mood across that tag's entries
/// compares to the 1–5 scale.
struct StatsTagCorrelationCard: View {
    let correlations: [StatisticsCalculator.TagMoodCorrelation]
    let moodLevel: Int

    private let displayLimit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if correlations.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(correlations.prefix(displayLimit)) { correlation in
                        row(correlation)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tag patterns").eyebrowStyle()
            Text("How each tag tends to feel")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
        }
    }

    private var emptyState: some View {
        Text("Add tags and moods to your entries to see patterns here.")
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)
    }

    private func row(_ c: StatisticsCalculator.TagMoodCorrelation) -> some View {
        let level = max(1, min(5, Int(round(c.averageMood))))
        let fraction = max(0.05, min(1.0, (c.averageMood - 1.0) / 4.0))
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("#\(c.tag)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText)
                Spacer(minLength: 8)
                Text("\(c.count) · \(String(format: "%.1f", c.averageMood))")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MiraPalette.primaryText.opacity(0.06))
                    Capsule()
                        .fill(MiraPalette.mood(level: level))
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }
}
