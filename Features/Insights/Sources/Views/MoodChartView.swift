import SwiftUI
import Charts
import CoreKit
import Utilities
import DesignSystem

public struct MoodChartView: View {
    private let dailyAverages: [MoodDailyAverage]
    private let topTags: [MoodByTag]
    private let overallAverage: Double?
    private let entryCount: Int

    public init(entries: [EntrySnapshot], tagLimit: Int = 5) {
        self.dailyAverages = MoodAnalytics.moodByDay(entries: entries)
        self.topTags = Array(MoodAnalytics.moodByTag(entries: entries).prefix(tagLimit))
        self.overallAverage = MoodAnalytics.averageMood(entries: entries)
        self.entryCount = entries.compactMap(\.mood).count
    }

    public var body: some View {
        GlassCard(
            tintLevel: overallAverage.map { level(for: $0) },
            cornerRadius: 24,
            padding: 20
        ) {
            VStack(alignment: .leading, spacing: 18) {
                header
                if dailyAverages.isEmpty {
                    emptyState
                } else {
                    trendChart
                    if !topTags.isEmpty {
                        Divider()
                            .overlay(MiraPalette.primaryText.opacity(0.08))
                        tagsChart
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mood").eyebrowStyle()
                if entryCount > 0 {
                    Text("\(entryCount) entries with a mood")
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                }
            }
            Spacer()
            if let average = overallAverage {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", average))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(MiraPalette.mood(level: level(for: average)))
                    Text("/ 5")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MiraPalette.secondaryText)
                }
            }
        }
    }

    // MARK: - Trend

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
            .symbolSize(60)
            .foregroundStyle(MiraPalette.mood(level: level(for: point.average)))
        }
        .chartYScale(domain: 0.8...5.2)
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4, 5]) { _ in
                AxisGridLine().foregroundStyle(MiraPalette.primaryText.opacity(0.08))
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
        .frame(height: 170)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                MiraPalette.mood(level: 5).opacity(0.38),
                MiraPalette.mood(level: 3).opacity(0.22),
                MiraPalette.mood(level: 1).opacity(0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Tags

    private var tagsChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mood by tag").eyebrowStyle()
            Chart(topTags) { row in
                BarMark(
                    x: .value("Average", row.average),
                    y: .value("Tag", row.tag)
                )
                .cornerRadius(6)
                .foregroundStyle(MiraPalette.mood(level: level(for: row.average)))
                .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                    Text(String(format: "%.1f", row.average))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MiraPalette.secondaryText)
                }
            }
            .chartXScale(domain: 1...5)
            .chartXAxis {
                AxisMarks(values: [1, 3, 5]) { _ in
                    AxisGridLine().foregroundStyle(MiraPalette.primaryText.opacity(0.06))
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(MiraPalette.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.8))
                }
            }
            .frame(height: CGFloat(topTags.count) * 30 + 16)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing to chart yet")
                .font(MiraTypography.entryBodyEmphasized)
                .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
            Text("Log entries with a mood and the trend appears here.")
                .font(.system(size: 13))
                .foregroundStyle(MiraPalette.secondaryText)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private func level(for average: Double) -> Int {
        max(1, min(5, Int(round(average))))
    }
}
