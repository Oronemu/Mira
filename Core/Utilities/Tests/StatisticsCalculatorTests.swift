import Foundation
import Testing
import CoreKit
@testable import Utilities

@Suite("StatisticsCalculator")
struct StatisticsCalculatorTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func entry(daysAgo: Int, mood: Int? = nil, words: String = "hello world", asOf: Date) -> EntrySnapshot {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: asOf))!
        return EntrySnapshot(
            createdAt: date,
            plainContent: words,
            mood: mood.flatMap { Mood(rawValue: $0) }
        )
    }

    // MARK: - Streak

    @Test("empty entries → zero streak")
    func emptyStreak() {
        let s = StatisticsCalculator.streak(entries: [], asOf: .now, calendar: calendar)
        #expect(s.current == 0)
        #expect(s.best == 0)
        #expect(s.bestStartDate == nil)
    }

    @Test("single entry today → 1/1")
    func singleToday() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let s = StatisticsCalculator.streak(
            entries: [entry(daysAgo: 0, asOf: now)],
            asOf: now,
            calendar: calendar
        )
        #expect(s.current == 1)
        #expect(s.best == 1)
    }

    @Test("today empty but yesterday counted → current still 1")
    func yesterdayCarriesForward() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let s = StatisticsCalculator.streak(
            entries: [entry(daysAgo: 1, asOf: now)],
            asOf: now,
            calendar: calendar
        )
        #expect(s.current == 1)
        #expect(s.best == 1)
    }

    @Test("3-day run with gap then 2-day run → current=0, best=3")
    func bestPicksLongestSpan() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let entries = [
            entry(daysAgo: 10, asOf: now),
            entry(daysAgo: 9, asOf: now),
            entry(daysAgo: 8, asOf: now),
            // gap
            entry(daysAgo: 4, asOf: now),
            entry(daysAgo: 3, asOf: now),
        ]
        let s = StatisticsCalculator.streak(entries: entries, asOf: now, calendar: calendar)
        #expect(s.current == 0)
        #expect(s.best == 3)
    }

    @Test("multiple entries on same day count as one streak day")
    func dedupSameDay() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let entries = [
            entry(daysAgo: 0, asOf: now),
            entry(daysAgo: 0, asOf: now),
            entry(daysAgo: 1, asOf: now),
        ]
        let s = StatisticsCalculator.streak(entries: entries, asOf: now, calendar: calendar)
        #expect(s.current == 2)
        #expect(s.best == 2)
    }

    // MARK: - Mood counters

    @Test("counters split moods into good/steady/low")
    func countersSplit() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let entries = [
            entry(daysAgo: 0, mood: 5, asOf: now),
            entry(daysAgo: 1, mood: 4, asOf: now),
            entry(daysAgo: 2, mood: 3, asOf: now),
            entry(daysAgo: 3, mood: 2, asOf: now),
            entry(daysAgo: 4, mood: 1, asOf: now),
            entry(daysAgo: 5, mood: nil, asOf: now), // ignored
        ]
        let c = StatisticsCalculator.moodCounters(entries: entries)
        #expect(c.good == 2)
        #expect(c.steady == 1)
        #expect(c.low == 2)
        #expect(c.total == 5)
    }

    // MARK: - Weekday

    @Test("weekday buckets respect calendar firstWeekday ordering")
    func weekdayOrdering() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let buckets = StatisticsCalculator.moodByWeekday(
            entries: [entry(daysAgo: 0, mood: 4, asOf: now)],
            calendar: cal
        )
        #expect(buckets.count == 7)
        // First bucket should be Monday (weekday=2 in Gregorian).
        #expect(buckets.first?.weekday == 2)
        // Last should be Sunday (weekday=1).
        #expect(buckets.last?.weekday == 1)
    }

    // MARK: - Words

    @Test("totalWords splits on whitespace")
    func wordCount() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let entries = [
            entry(daysAgo: 0, words: "one two three", asOf: now),
            entry(daysAgo: 1, words: "  spaced   out  ", asOf: now),
            entry(daysAgo: 2, words: "", asOf: now),
        ]
        let count = StatisticsCalculator.totalWords(entries: entries)
        #expect(count == 5)
    }

    // MARK: - Range

    @Test("range filtering keeps only entries inside window")
    func rangeFiltering() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let entries = [
            entry(daysAgo: 1, asOf: now),
            entry(daysAgo: 6, asOf: now),
            entry(daysAgo: 8, asOf: now),  // outside week
            entry(daysAgo: 40, asOf: now), // outside month
        ]
        let week = StatisticsCalculator.entries(entries, in: .week, asOf: now, calendar: calendar)
        let month = StatisticsCalculator.entries(entries, in: .month, asOf: now, calendar: calendar)
        #expect(week.count == 2)
        #expect(month.count == 3)
    }

    // MARK: - Heatmap

    @Test("heatmap returns 53*7 cells ending at current week")
    func heatmapShape() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let cells = StatisticsCalculator.yearHeatmap(entries: [], asOf: now, calendar: calendar)
        #expect(cells.count == 53 * 7)
    }

    @Test("heatmap counts entries per day and averages mood")
    func heatmapBuckets() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let entries = [
            entry(daysAgo: 1, mood: 5, asOf: now),
            entry(daysAgo: 1, mood: 3, asOf: now),
            entry(daysAgo: 2, mood: 4, asOf: now),
        ]
        let cells = StatisticsCalculator.yearHeatmap(entries: entries, asOf: now, calendar: calendar)
        let yesterday = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        )
        let dayBefore = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now))!
        )
        let yCell = cells.first { $0.date == yesterday }
        let dCell = cells.first { $0.date == dayBefore }
        #expect(yCell?.count == 2)
        #expect(yCell?.averageMood == 4.0)
        #expect(dCell?.count == 1)
        #expect(dCell?.averageMood == 4.0)
    }
}
