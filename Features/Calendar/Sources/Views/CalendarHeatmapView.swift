import SwiftUI
import CoreKit
import DesignSystem

/// One month rendered as a 7-column heatmap grid in the emotional-journal
/// palette. Each cell carries the day's average-mood fill (stronger for
/// higher moods), a small row of dots underneath showing the entry count,
/// and — for today — a ring in the matching mood color.
public struct CalendarHeatmapView: View {
    private let month: Date
    private let state: CalendarState
    private let onSelectDay: (Date) -> Void

    public init(month: Date, state: CalendarState, onSelectDay: @escaping (Date) -> Void) {
        self.month = month
        self.state = state
        self.onSelectDay = onSelectDay
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    public var body: some View {
        VStack(spacing: 10) {
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(MonthGrid.cells(for: month).enumerated()), id: \.offset) { _, cell in
                    cellView(cell)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(MonthGrid.weekdaySymbols(), id: \.self) { symbol in
                Text(symbol)
                    .eyebrowStyle()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: MonthGrid.Cell) -> some View {
        if let date = cell.date {
            DayCell(
                date: date,
                averageMood: state.averageMood(on: date),
                entryCount: state.entryCount(on: date),
                onTap: { onSelectDay(date) }
            )
        } else {
            Color.clear.aspectRatio(1, contentMode: .fit)
        }
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date: Date
    let averageMood: Double?
    let entryCount: Int
    let onTap: () -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .semibold : .regular, design: .serif))
                    .foregroundStyle(textColor)

                if entryCount > 0 {
                    countDots
                        .frame(height: 4)
                } else {
                    Color.clear.frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundFill)
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(todayBorder, lineWidth: 1.5)
                } else if hasMood {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(MiraPalette.primaryText.opacity(0.06), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var isToday: Bool { calendar.isDateInToday(date) }
    private var hasMood: Bool { moodLevel != nil }

    private var moodLevel: Int? {
        averageMood.map { max(1, min(5, Int(round($0)))) }
    }

    private var backgroundFill: Color {
        if let level = moodLevel {
            return MiraPalette.mood(level: level).opacity(moodOpacity)
        }
        if entryCount > 0 {
            return MiraPalette.secondaryBackground.opacity(0.6)
        }
        return .clear
    }

    /// Stronger fill for higher mood levels — 1 → 0.22, 5 → 0.54.
    private var moodOpacity: Double {
        guard let level = moodLevel else { return 0.18 }
        return 0.22 + Double(level - 1) * 0.08
    }

    private var textColor: Color {
        hasMood || entryCount > 0
            ? MiraPalette.primaryText.opacity(0.9)
            : MiraPalette.secondaryText.opacity(0.7)
    }

    private var todayBorder: Color {
        moodLevel.map { MiraPalette.mood(level: $0) } ?? MiraPalette.accent
    }

    @ViewBuilder
    private var countDots: some View {
        let visible = min(entryCount, 3)
        HStack(spacing: 2) {
            ForEach(0..<visible, id: \.self) { _ in
                Circle()
                    .fill(MiraPalette.primaryText.opacity(0.55))
                    .frame(width: 3, height: 3)
            }
            if entryCount > 3 {
                Text("+")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.55))
            }
        }
    }

    private var accessibilityLabel: String {
        let dayString = date.formatted(.dateTime.day().month())
        if entryCount == 0 {
            return "\(dayString), no entries"
        }
        return "\(dayString), \(entryCount) entries"
    }
}
