import Foundation
import WidgetKit
import CoreKit
import Persistence
import Utilities

struct StreakProvider: TimelineProvider {
    typealias Entry = StreakEntry

    /// When `true`, the provider checks `WidgetEntitlementsStore` and
    /// emits a `isLocked` entry for free users. Home Streak widget
    /// uses `false` (always free); Lock Screen / Pro widgets use
    /// `true` so they degrade gracefully.
    let requiresPro: Bool

    init(requiresPro: Bool = false) {
        self.requiresPro = requiresPro
    }

    func placeholder(in context: Context) -> StreakEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let box = SendableBox(value: completion)
        Task {
            let entry = await loadEntry()
            box.value(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let box = SendableBox(value: completion)
        Task {
            let entry = await loadEntry()
            // Streak only changes at day boundaries, but we also want to
            // pick up new writes; refresh hourly.
            let next = Date.now.addingTimeInterval(60 * 60)
            box.value(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    @MainActor
    private func loadEntry() async -> StreakEntry {
        if requiresPro && !WidgetEntitlementsStore().isPro() {
            return StreakEntry(
                date: .now,
                streak: 0,
                latestEntry: nil,
                moodSparkline: Array(repeating: nil, count: 7),
                isLocked: true
            )
        }
        do {
            let container = try ModelContainerFactory.live(appGroup: WidgetAppGroup.identifier)
            let repository = SwiftDataEntryRepository(modelContainer: container)
            let entries = try await repository.fetch(matching: .all)
            let streak = StreakCalculator.currentStreak(entries: entries)
            return StreakEntry(
                date: .now,
                streak: streak,
                latestEntry: entries.first,
                moodSparkline: Self.sparkline(entries: entries),
                isLocked: false
            )
        } catch {
            return .placeholder
        }
    }

    /// Builds the 7-cell sparkline ending today. Days without a mood log
    /// surface as `nil` so the widget can render a muted placeholder.
    static func sparkline(entries: [EntrySnapshot], calendar: Calendar = .current) -> [Int?] {
        let daily = MoodAnalytics.moodByDay(entries: entries, calendar: calendar)
        let byDay = Dictionary(uniqueKeysWithValues: daily.map { ($0.day, $0.average) })
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset -> Int? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today),
                  let average = byDay[date]
            else { return nil }
            return max(1, min(5, Int(round(average))))
        }
    }
}

private struct SendableBox<T>: @unchecked Sendable {
    let value: T
}
