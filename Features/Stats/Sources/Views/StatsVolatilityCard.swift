import SwiftUI
import CoreKit
import Utilities
import DesignSystem

/// Pro card — visualises mood volatility (population σ of moods) over
/// the selected range. A horizontal "steady → stormy" gradient bar
/// carries a marker dot at the user's current σ, with a one-word
/// bucket label and the sample count below.
struct StatsVolatilityCard: View {
    let volatility: StatisticsCalculator.MoodVolatility?
    let rangeSubtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let v = volatility {
                spectrum(v)
                caption(v)
            } else {
                emptyState
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Steadiness").eyebrowStyle()
            Text("How steady your mood feels")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
        }
    }

    private var emptyState: some View {
        Text("Need a few moods in this range to gauge swings.")
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)
    }

    private func spectrum(_ v: StatisticsCalculator.MoodVolatility) -> some View {
        // Marker rides a calm-good → stormy-low gradient. Position is
        // clamped a few pixels off each edge so the dot never gets
        // visually clipped by the capsule's rounded ends.
        GeometryReader { proxy in
            let barWidth = proxy.size.width
            let markerX = max(8, min(barWidth - 8, barWidth * v.fraction))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        colors: [
                            MiraPalette.mood(level: 4).opacity(0.55),
                            MiraPalette.mood(level: 3).opacity(0.50),
                            MiraPalette.mood(level: 1).opacity(0.55),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 10)
                    .frame(maxHeight: .infinity, alignment: .center)
                Circle()
                    .fill(MiraPalette.primaryText)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().strokeBorder(MiraPalette.background, lineWidth: 2)
                    )
                    .position(x: markerX, y: 7)
            }
        }
        .frame(height: 14)
    }

    private func caption(_ v: StatisticsCalculator.MoodVolatility) -> some View {
        let label: LocalizedStringKey = switch v.level {
        case .steady: "Steady"
        case .gentle: "Gentle swings"
        case .strong: "Strong swings"
        }
        let bucket = Text(label)
            .font(.system(size: 14, weight: .semibold, design: .serif))
            .foregroundStyle(MiraPalette.primaryText)
        let entries = Text(String(format: String(localized: "%lld entries"), v.count))
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
        let range = Text(rangeSubtitle)
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
        let dot = Text("·").foregroundStyle(.secondary)

        // Horizontal one-liner fits English comfortably; in Russian the
        // labels grow and would wrap mid-phrase, so fall back to a
        // two-row layout (bucket on its own line, metadata beneath).
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                bucket
                dot
                entries
                dot
                range
            }
            .lineLimit(1)

            VStack(alignment: .leading, spacing: 4) {
                bucket
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    entries
                    dot
                    range
                }
            }
        }
    }
}
