import SwiftUI
import Charts
import CoreKit
import Utilities
import DesignSystem

/// Hero of the Stats screen — line + soft area fill of average mood per
/// day across the selected range. Mirrors the visual language of the
/// existing MoodChartView (same gradient direction and color palette) but
/// tighter and without the per-tag chart, since this is the headline.
struct StatsMoodTrendCard: View {
    let dailyAverages: [MoodDailyAverage]
    let entryCount: Int
    let overallAverage: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if dailyAverages.isEmpty {
                emptyState
            } else {
                trendChart
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How you've been", comment: "Stats — mood trend hero card title")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
            if let avg = overallAverage {
                Text(
                    "Avg \(formatted(avg)) · \(entryCount) entries",
                    comment: "Stats — mood trend subtitle: avg score and entry count"
                )
                .eyebrowStyle()
            } else {
                Text("Add a mood to see your trend", comment: "Stats — empty mood-trend subtitle")
                    .eyebrowStyle()
            }
        }
    }

    // MARK: - Chart

    private var trendChart: some View {
        Chart(dailyAverages) { point in
            AreaMark(
                x: .value("Day", point.day),
                y: .value("Mood", point.average)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(areaGradient)

            LineMark(
                x: .value("Day", point.day),
                y: .value("Mood", point.average)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(MiraPalette.primaryText.opacity(0.55))
            .lineStyle(StrokeStyle(lineWidth: 1.4, lineCap: .round))

            PointMark(
                x: .value("Day", point.day),
                y: .value("Mood", point.average)
            )
            .symbolSize(50)
            .foregroundStyle(MiraPalette.mood(level: level(for: point.average)))
        }
        .chartYScale(domain: 0.8...5.2)
        .chartYAxis {
            AxisMarks(values: [1, 3, 5]) { _ in
                AxisGridLine().foregroundStyle(MiraPalette.primaryText.opacity(0.06))
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(MiraPalette.secondaryText)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(format: .dateTime.day().month(.narrow))
                    .font(.system(size: 10))
                    .foregroundStyle(MiraPalette.secondaryText)
            }
        }
        .frame(height: 180)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                MiraPalette.mood(level: 5).opacity(0.36),
                MiraPalette.mood(level: 3).opacity(0.20),
                MiraPalette.mood(level: 1).opacity(0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(MiraPalette.secondaryText.opacity(0.6))
            Text("Nothing to chart yet", comment: "Stats — mood-trend empty state title")
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func level(for average: Double) -> Int {
        max(1, min(5, Int(round(average))))
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
