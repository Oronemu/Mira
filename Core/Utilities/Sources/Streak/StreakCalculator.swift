import Foundation
import CoreKit

/// Pure helper computing the consecutive-day writing streak ending at `date`.
/// Used by widgets, insights, and any future analytics surface.
public enum StreakCalculator {
    /// Number of consecutive days (ending today, inclusive) on which the user
    /// wrote at least one entry. Returns 0 when today has no entries.
    public static func currentStreak(
        entries: [EntrySnapshot],
        asOf date: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard !entries.isEmpty else { return 0 }
        let dayWithEntry: Set<Date> = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })

        var streak = 0
        var cursor = calendar.startOfDay(for: date)
        while dayWithEntry.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Longest run of consecutive days the user wrote, anywhere in history.
    public static func longestStreak(
        entries: [EntrySnapshot],
        calendar: Calendar = .current
    ) -> Int {
        guard !entries.isEmpty else { return 0 }
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        let sorted = days.sorted()

        var best = 1
        var current = 1
        for index in 1..<sorted.count {
            if let next = calendar.date(byAdding: .day, value: 1, to: sorted[index - 1]),
               next == sorted[index] {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
}
