import SwiftUI
import CoreKit
import Utilities
import DesignSystem

/// Pro card — 7-day mood forecast based on weekday averages. Each day
/// renders as a colour-tinted dot whose opacity reflects the
/// confidence (cold-start days fade out so users don't read into noise).
struct StatsForecastCard: View {
    let predictions: [StatisticsCalculator.DayPrediction]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Looking ahead").eyebrowStyle()
                Text("Predicted mood for the week")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(predictions) { prediction in
                    cell(prediction)
                        .frame(maxWidth: .infinity)
                }
            }

            Text("Built from your weekday averages. Faded days have less history to lean on.")
                .font(MiraTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func cell(_ p: StatisticsCalculator.DayPrediction) -> some View {
        let level = max(1, min(5, Int(round(p.predictedMood))))
        let opacity = 0.35 + (0.65 * p.confidence)
        return VStack(spacing: 6) {
            Text(p.date, format: .dateTime.weekday(.abbreviated))
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)

            Circle()
                .fill(MiraPalette.mood(level: level).opacity(opacity))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle().strokeBorder(MiraPalette.primaryText.opacity(0.08), lineWidth: 0.5)
                )

            Text(p.date, format: .dateTime.day())
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(MiraPalette.primaryText.opacity(0.75))
        }
    }
}
