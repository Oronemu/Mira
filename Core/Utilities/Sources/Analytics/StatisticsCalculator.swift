import Foundation
import CoreKit

/// Pure-function aggregates that drive the Stats screen. Kept off `MoodAnalytics`
/// so the existing chart paths stay stable while richer stats land here.
public enum StatisticsCalculator {

    // MARK: - Range

    /// Selectable time window for stats that vary by period.
    public enum Range: Sendable, Hashable, CaseIterable {
        case week
        case month
        case year

        /// Half-open interval ending at `now`, going back the named span.
        /// Week = last 7 days, month = last 30, year = last 365 — chosen
        /// for cleaner UI math than calendar-aligned ranges.
        public func dateInterval(asOf now: Date, calendar: Calendar = .current) -> DateInterval {
            let days: Int
            switch self {
            case .week: days = 7
            case .month: days = 30
            case .year: days = 365
            }
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
                ?? now
            let start = calendar.date(byAdding: .day, value: -days, to: endOfToday) ?? now
            return DateInterval(start: start, end: endOfToday)
        }
    }

    public static func entries(
        _ entries: [EntrySnapshot],
        in range: Range,
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> [EntrySnapshot] {
        let interval = range.dateInterval(asOf: now, calendar: calendar)
        return entries.filter { interval.contains($0.createdAt) }
    }

    // MARK: - Streak

    public struct Streak: Sendable, Hashable {
        public let current: Int
        public let best: Int
        public let bestStartDate: Date?

        public init(current: Int, best: Int, bestStartDate: Date?) {
            self.current = current
            self.best = best
            self.bestStartDate = bestStartDate
        }
    }

    /// "Current" counts back from today as long as days are consecutive — if
    /// today has no entry yet, we still extend the run from yesterday so a
    /// fresh-morning launch doesn't say "0 days". "Best" walks the full
    /// history once and returns the longest unbroken span.
    public static func streak(
        entries: [EntrySnapshot],
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> Streak {
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.isEmpty else {
            return Streak(current: 0, best: 0, bestStartDate: nil)
        }

        let today = calendar.startOfDay(for: now)
        let cursor: Date = days.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var current = 0
        var walker = cursor
        while days.contains(walker) {
            current += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: walker) else { break }
            walker = prev
        }

        // Walk every entry day in order to find the longest run.
        let sorted = days.sorted()
        var best = 0
        var bestStart: Date? = nil
        var run = 1
        var runStart = sorted.first ?? today
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let day = sorted[i]
            let expected = calendar.date(byAdding: .day, value: 1, to: prev) ?? prev
            if calendar.isDate(day, inSameDayAs: expected) {
                run += 1
            } else {
                if run > best {
                    best = run
                    bestStart = runStart
                }
                run = 1
                runStart = day
            }
        }
        if run > best {
            best = run
            bestStart = runStart
        }
        if sorted.count == 1 {
            best = 1
            bestStart = sorted[0]
        }

        return Streak(current: current, best: best, bestStartDate: bestStart)
    }

    // MARK: - Mood counters

    public struct MoodCounters: Sendable, Hashable {
        public let good: Int   // mood 4-5
        public let steady: Int // mood 3
        public let low: Int    // mood 1-2
        public let total: Int  // entries with any mood

        public init(good: Int, steady: Int, low: Int) {
            self.good = good
            self.steady = steady
            self.low = low
            self.total = good + steady + low
        }
    }

    public static func moodCounters(entries: [EntrySnapshot]) -> MoodCounters {
        var good = 0, steady = 0, low = 0
        for entry in entries {
            guard let mood = entry.mood else { continue }
            switch mood.rawValue {
            case 4, 5: good += 1
            case 3: steady += 1
            case 1, 2: low += 1
            default: break
            }
        }
        return MoodCounters(good: good, steady: steady, low: low)
    }

    // MARK: - Mood by weekday

    public struct WeekdayMood: Sendable, Hashable, Identifiable {
        /// `Calendar.component(.weekday, ...)` value: 1 = Sunday … 7 = Saturday.
        public let weekday: Int
        public let average: Double
        public let count: Int

        public var id: Int { weekday }

        public init(weekday: Int, average: Double, count: Int) {
            self.weekday = weekday
            self.average = average
            self.count = count
        }
    }

    /// Returns 7 buckets ordered by the calendar's `firstWeekday` so the
    /// chart axis lines up with the user's locale (Mon-first in RU, Sun-first
    /// in en_US). Buckets without any mood entries return `average: 0,
    /// count: 0` so the view can render an empty bar in place rather than
    /// collapsing the row.
    public static func moodByWeekday(
        entries: [EntrySnapshot],
        calendar: Calendar = .current
    ) -> [WeekdayMood] {
        var buckets: [Int: [Double]] = [:]
        for entry in entries {
            guard let mood = entry.mood else { continue }
            let weekday = calendar.component(.weekday, from: entry.createdAt)
            buckets[weekday, default: []].append(Double(mood.rawValue))
        }
        let firstWeekday = calendar.firstWeekday
        return (0..<7).map { offset in
            let wd = ((firstWeekday - 1 + offset) % 7) + 1
            let values = buckets[wd] ?? []
            let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            return WeekdayMood(weekday: wd, average: avg, count: values.count)
        }
    }

    // MARK: - Words

    public static func totalWords(entries: [EntrySnapshot]) -> Int {
        entries.reduce(0) { acc, entry in
            acc + entry.plainContent
                .split(omittingEmptySubsequences: true) { $0.isWhitespace || $0.isNewline }
                .count
        }
    }

    // MARK: - Year heatmap

    public struct HeatmapCell: Sendable, Hashable, Identifiable {
        public let date: Date
        public let count: Int
        public let averageMood: Double?

        public var id: Date { date }

        public init(date: Date, count: Int, averageMood: Double?) {
            self.date = date
            self.count = count
            self.averageMood = averageMood
        }
    }

    /// 371-cell grid (53 weeks × 7 days) ending at the week of `now`. The
    /// view paints these in column-major order so the chart reads like a
    /// year strip — leftmost column is the oldest week, rightmost the
    /// current one. Days outside the user's actual entry history are still
    /// returned (with `count: 0`) so the grid stays rectangular.
    public static func yearHeatmap(
        entries: [EntrySnapshot],
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> [HeatmapCell] {
        // Bucket entries by start-of-day for O(1) lookup.
        var buckets: [Date: [Double]] = [:]
        var counts: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.createdAt)
            counts[day, default: 0] += 1
            if let mood = entry.mood {
                buckets[day, default: []].append(Double(mood.rawValue))
            }
        }

        // End at the last day of the current week (calendar.firstWeekday-aware).
        let today = calendar.startOfDay(for: now)
        let weekdayToday = calendar.component(.weekday, from: today)
        let daysToWeekEnd = ((calendar.firstWeekday + 6 - weekdayToday) + 7) % 7
        let lastCellDay = calendar.date(byAdding: .day, value: daysToWeekEnd, to: today) ?? today

        let totalCells = 53 * 7
        var cells: [HeatmapCell] = []
        cells.reserveCapacity(totalCells)
        for offset in (0..<totalCells).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: lastCellDay) else {
                continue
            }
            let normalised = calendar.startOfDay(for: day)
            let count = counts[normalised] ?? 0
            let moods = buckets[normalised] ?? []
            let avg = moods.isEmpty ? nil : moods.reduce(0, +) / Double(moods.count)
            cells.append(HeatmapCell(date: normalised, count: count, averageMood: avg))
        }
        return cells
    }
}
