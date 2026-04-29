import Foundation
import CoreKit

/// One-day mood aggregate used by charts.
public struct MoodDailyAverage: Sendable, Hashable, Identifiable {
    public let day: Date
    public let average: Double
    public let count: Int

    public var id: Date { day }

    public init(day: Date, average: Double, count: Int) {
        self.day = day
        self.average = average
        self.count = count
    }
}

/// Per-tag mood summary for "mood × tag" correlations.
public struct MoodByTag: Sendable, Hashable, Identifiable {
    public let tag: String
    public let average: Double
    public let count: Int

    public var id: String { tag }

    public init(tag: String, average: Double, count: Int) {
        self.tag = tag
        self.average = average
        self.count = count
    }
}

public enum MoodAnalytics {
    /// Overall mean mood across entries that have one. Returns nil when
    /// there's nothing to average over.
    public static func averageMood(entries: [EntrySnapshot]) -> Double? {
        let values = entries.compactMap(\.mood).map { Double($0.rawValue) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Average mood per day, sorted ascending by date.
    public static func moodByDay(
        entries: [EntrySnapshot],
        calendar: Calendar = .current
    ) -> [MoodDailyAverage] {
        var buckets: [Date: [Double]] = [:]
        for entry in entries {
            guard let mood = entry.mood else { continue }
            let day = calendar.startOfDay(for: entry.createdAt)
            buckets[day, default: []].append(Double(mood.rawValue))
        }
        return buckets
            .map { day, values in
                MoodDailyAverage(day: day, average: values.reduce(0, +) / Double(values.count), count: values.count)
            }
            .sorted { $0.day < $1.day }
    }

    /// Average mood per tag, sorted by sample count descending. Only
    /// surfaces tags with `minCount` or more entries so one-off tags
    /// don't dominate the chart.
    public static func moodByTag(
        entries: [EntrySnapshot],
        minCount: Int = 2
    ) -> [MoodByTag] {
        var buckets: [String: [Double]] = [:]
        for entry in entries {
            guard let mood = entry.mood else { continue }
            for tag in entry.tags {
                buckets[tag, default: []].append(Double(mood.rawValue))
            }
        }
        return buckets
            .compactMap { tag, values -> MoodByTag? in
                guard values.count >= minCount else { return nil }
                return MoodByTag(
                    tag: tag,
                    average: values.reduce(0, +) / Double(values.count),
                    count: values.count
                )
            }
            .sorted { $0.count > $1.count }
    }
}
