import SwiftUI
import Charts
import Utilities
import DesignSystem

/// Mood-by-weekday bar chart. Bars are tinted by each day's average mood
/// (so a 4.6-Saturday glows warm-yellow, a 2.1-Monday goes muted); empty
/// days show as a barely-there outline so the row doesn't collapse.
/// Subtitle highlights the best day when there's a clear winner.
struct StatsWeekdayCard: View {
    let weekdayMoods: [Utilities.StatisticsCalculator.WeekdayMood]
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if hasAnyData {
                chart
            } else {
                emptyState
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Best days", comment: "Stats — weekday mood card title")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
            Text(subtitleText)
                .eyebrowStyle()
        }
    }

    private var subtitleText: String {
        if let bestDay {
            return String(
                localized: "\(bestDay) edge ahead",
                comment: "Stats — weekday subtitle, %@ is a weekday name (e.g. Saturdays)"
            )
        }
        return String(localized: "How your moods vary across the week", comment: "Stats — weekday neutral subtitle")
    }

    private var bestDay: String? {
        let withData = weekdayMoods.filter { $0.count > 0 }
        guard let top = withData.max(by: { $0.average < $1.average }),
              let runnerUp = withData.filter({ $0.weekday != top.weekday }).max(by: { $0.average < $1.average }),
              top.average - runnerUp.average >= 0.4
        else { return nil }
        return calendar.standaloneWeekdaySymbols[(top.weekday - 1) % 7] + "s"
    }

    // MARK: - Chart

    private var hasAnyData: Bool { weekdayMoods.contains { $0.count > 0 } }

    private var chart: some View {
        Chart(weekdayMoods) { row in
            BarMark(
                x: .value("Day", shortSymbol(for: row.weekday)),
                y: .value("Mood", max(row.average, 0.001))
            )
            .cornerRadius(6)
            .foregroundStyle(barColor(for: row))
        }
        .chartYScale(domain: 0...5.4)
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
                AxisValueLabel()
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(MiraPalette.secondaryText)
            }
        }
        .frame(height: 130)
    }

    private func barColor(for row: Utilities.StatisticsCalculator.WeekdayMood) -> Color {
        guard row.count > 0 else {
            return MiraPalette.primaryText.opacity(0.06)
        }
        let level = max(1, min(5, Int(round(row.average))))
        return MiraPalette.mood(level: level).opacity(0.85)
    }

    private func shortSymbol(for weekday: Int) -> String {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let idx = (weekday - 1) % symbols.count
        return symbols[idx]
    }

    // MARK: - Empty

    private var emptyState: some View {
        Text("Log entries with a mood to see weekly patterns.", comment: "Stats — weekday empty state")
            .font(.system(size: 13))
            .foregroundStyle(MiraPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
