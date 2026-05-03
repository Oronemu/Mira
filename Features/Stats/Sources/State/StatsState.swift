import Foundation
import Observation
import CoreKit
import Utilities

/// State container for the Stats screen. Subscribes to entry, insight, and
/// AskMira chat streams so cards stay live when the user creates an entry
/// in another tab and pops back here. The `range` toggles only the
/// `inRange*` slices — streak, heatmap, and Mira-counter cards are always
/// computed from the full history.
@MainActor
@Observable
public final class StatsState {

    public var range: StatisticsCalculator.Range = .month {
        didSet { /* derived properties read range live */ }
    }

    public private(set) var allEntries: [EntrySnapshot] = []
    public private(set) var insightCount: Int = 0
    public private(set) var chatCount: Int = 0
    public private(set) var isLoading: Bool = true

    private let entryRepository: any EntryRepository
    private let insightRepository: any InsightRepository
    private let askMiraRepository: any AskMiraRepository
    private let clock: @Sendable () -> Date

    private var entriesObservation: Task<Void, Never>?
    private var insightsObservation: Task<Void, Never>?
    private var chatsObservation: Task<Void, Never>?

    public init(
        entryRepository: any EntryRepository,
        insightRepository: any InsightRepository,
        askMiraRepository: any AskMiraRepository,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.entryRepository = entryRepository
        self.insightRepository = insightRepository
        self.askMiraRepository = askMiraRepository
        self.clock = clock
    }

    public func observe() async {
        if entriesObservation == nil {
            entriesObservation = Task { [weak self, entryRepository] in
                for await snapshot in entryRepository.observe(query: .all) {
                    await MainActor.run {
                        self?.allEntries = snapshot
                        self?.isLoading = false
                    }
                }
            }
        }
        if insightsObservation == nil {
            insightsObservation = Task { [weak self, insightRepository] in
                for await snapshot in insightRepository.observeAll() {
                    await MainActor.run {
                        self?.insightCount = snapshot.count
                    }
                }
            }
        }
        if chatsObservation == nil {
            chatsObservation = Task { [weak self, askMiraRepository] in
                for await snapshot in askMiraRepository.observeChats() {
                    await MainActor.run {
                        self?.chatCount = snapshot.count
                    }
                }
            }
        }
    }

    // MARK: - Derived

    /// Entries inside the currently selected range, used by every card whose
    /// summary is range-scoped (mood trend, counters, weekday, total words).
    public var entriesInRange: [EntrySnapshot] {
        StatisticsCalculator.entries(allEntries, in: range, asOf: clock())
    }

    public var streak: StatisticsCalculator.Streak {
        StatisticsCalculator.streak(entries: allEntries, asOf: clock())
    }

    public var moodCounters: StatisticsCalculator.MoodCounters {
        StatisticsCalculator.moodCounters(entries: entriesInRange)
    }

    public var weekdayMoods: [StatisticsCalculator.WeekdayMood] {
        StatisticsCalculator.moodByWeekday(entries: entriesInRange)
    }

    public var totalWords: Int {
        StatisticsCalculator.totalWords(entries: entriesInRange)
    }

    public var heatmapCells: [StatisticsCalculator.HeatmapCell] {
        StatisticsCalculator.yearHeatmap(entries: allEntries, asOf: clock())
    }

    public var dailyMoodAverages: [MoodDailyAverage] {
        MoodAnalytics.moodByDay(entries: entriesInRange)
    }

    public var averageMood: Double? {
        MoodAnalytics.averageMood(entries: entriesInRange)
    }

    public var entriesWithMoodCount: Int {
        entriesInRange.compactMap(\.mood).count
    }

    /// Mood-tinted level for the ambient background. Falls back to neutral
    /// (3) when there's no mood data so the screen never goes washed-out.
    public var ambientMoodLevel: Int {
        guard let avg = averageMood else { return 3 }
        return max(1, min(5, Int(round(avg))))
    }

    // MARK: - Pro derived

    /// Tag → average mood, restricted to tags with enough samples to be
    /// meaningful. Computed across the full history (not just the
    /// selected range) so the panel doesn't flicker as the range
    /// changes — patterns are stable, not weekly.
    public var tagCorrelations: [StatisticsCalculator.TagMoodCorrelation] {
        StatisticsCalculator.tagCorrelations(entries: allEntries)
    }

    /// Forecast for the next seven days, weekday-baseline model.
    public var weekdayPredictions: [StatisticsCalculator.DayPrediction] {
        StatisticsCalculator.weekdayPredictions(entries: allEntries, asOf: clock())
    }

    /// Mood volatility inside the selected range. Range-scoped — the
    /// user's swings shift week to week, and surfacing it as "your
    /// current state" is more honest than a lifetime average.
    public var moodVolatility: StatisticsCalculator.MoodVolatility? {
        StatisticsCalculator.moodVolatility(entries: entriesInRange)
    }
}
