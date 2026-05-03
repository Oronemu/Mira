import Foundation
import CoreKit

/// Pure-function progress evaluator for `Habit`. All callers (Stats
/// card, management screen) hand it the user's current entries and
/// receive a numeric snapshot. No persistence, no observation —
/// derivation only.
public enum HabitProgressCalculator {

    public struct Snapshot: Sendable, Hashable {
        /// Current count toward the active window's target.
        public let current: Int
        /// Target for the active window. Daily habits report `1`.
        public let target: Int
        /// Localised label of the window ("Today", "This week", "This month").
        public let windowLabel: WindowLabel

        public init(current: Int, target: Int, windowLabel: WindowLabel) {
            self.current = current
            self.target = target
            self.windowLabel = windowLabel
        }

        /// 0…1 fraction the UI can hand straight to ProgressView.
        public var fraction: Double {
            guard target > 0 else { return 0 }
            return min(1.0, Double(current) / Double(target))
        }

        public var isComplete: Bool { current >= target }
    }

    public enum WindowLabel: Sendable, Hashable {
        case today
        case thisWeek
        case thisMonth
    }

    public static func snapshot(
        for habit: Habit,
        entries: [EntrySnapshot],
        asOf now: Date = .now,
        calendar: Calendar = .current
    ) -> Snapshot {
        let matches = entries.filter { entry in
            entry.tags.contains { $0.lowercased() == habit.tag }
        }
        switch habit.cadence {
        case .daily:
            // "Daily" target is 1 — checked off if any tagged entry today.
            let today = calendar.startOfDay(for: now)
            let count = matches.contains { calendar.isDate($0.createdAt, inSameDayAs: today) } ? 1 : 0
            return Snapshot(current: count, target: 1, windowLabel: .today)

        case .weekly(let target):
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
                return Snapshot(current: 0, target: target, windowLabel: .thisWeek)
            }
            let count = matches.filter { interval.contains($0.createdAt) }.count
            return Snapshot(current: count, target: target, windowLabel: .thisWeek)

        case .monthly(let target):
            guard let interval = calendar.dateInterval(of: .month, for: now) else {
                return Snapshot(current: 0, target: target, windowLabel: .thisMonth)
            }
            let count = matches.filter { interval.contains($0.createdAt) }.count
            return Snapshot(current: count, target: target, windowLabel: .thisMonth)
        }
    }
}

/// Pure-function progress for `Goal`. Deadlines truncate the
/// counting window — entries past the deadline don't count, but the
/// goal stays visible so the user sees they ran out of time.
public enum GoalProgressCalculator {

    public struct Snapshot: Sendable, Hashable {
        public let current: Int
        public let target: Int
        public let isExpired: Bool

        public init(current: Int, target: Int, isExpired: Bool) {
            self.current = current
            self.target = target
            self.isExpired = isExpired
        }

        public var fraction: Double {
            guard target > 0 else { return 0 }
            return min(1.0, Double(current) / Double(target))
        }

        public var isComplete: Bool { current >= target }
    }

    public static func snapshot(
        for goal: Goal,
        entries: [EntrySnapshot],
        asOf now: Date = .now
    ) -> Snapshot {
        let isExpired = goal.deadline.map { $0 < now } ?? false
        let cutoff = goal.deadline ?? now
        let count = entries.filter { entry in
            guard entry.createdAt <= cutoff else { return false }
            return entry.tags.contains { $0.lowercased() == goal.tag }
        }.count
        return Snapshot(current: count, target: goal.targetCount, isExpired: isExpired)
    }
}
