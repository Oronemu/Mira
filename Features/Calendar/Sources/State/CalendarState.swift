import Foundation
import Observation
import CoreKit

@MainActor
@Observable
public final class CalendarState {
    public var currentMonth: Date
    public private(set) var entriesByDay: [Date: [EntrySnapshot]] = [:]
    public private(set) var isLoading: Bool = true

    public let availableMonths: [Date]
    private let repository: any EntryRepository
    private let calendar: Calendar

    public init(
        repository: any EntryRepository,
        calendar: Calendar = .current,
        currentMonth: Date = .now,
        monthsBack: Int = 12
    ) {
        self.repository = repository
        self.calendar = calendar
        let normalised = calendar.startOfMonth(currentMonth)
        self.currentMonth = normalised

        var months: [Date] = []
        for offset in stride(from: -monthsBack, through: 0, by: 1) {
            if let d = calendar.date(byAdding: .month, value: offset, to: normalised) {
                months.append(calendar.startOfMonth(d))
            }
        }
        self.availableMonths = months
    }

    public func observe() async {
        for await snapshot in repository.observe(query: .all) {
            isLoading = false
            entriesByDay = Dictionary(grouping: snapshot) { entry in
                self.calendar.startOfDay(for: entry.createdAt)
            }
        }
    }

    /// Average mood (1...5) for a given day, or nil when there are no entries.
    public func averageMood(on day: Date) -> Double? {
        let key = calendar.startOfDay(for: day)
        guard let entries = entriesByDay[key], !entries.isEmpty else { return nil }
        let moods = entries.compactMap { $0.mood?.rawValue }
        guard !moods.isEmpty else { return nil }
        return Double(moods.reduce(0, +)) / Double(moods.count)
    }

    public func entryCount(on day: Date) -> Int {
        let key = calendar.startOfDay(for: day)
        return entriesByDay[key]?.count ?? 0
    }

    // MARK: - Month navigation

    public var canGoToPreviousMonth: Bool {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth) else {
            return false
        }
        return availableMonths.contains(calendar.startOfMonth(prev))
    }

    public var canGoToNextMonth: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else {
            return false
        }
        return availableMonths.contains(calendar.startOfMonth(next))
    }

    public func goToPreviousMonth() {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth) else { return }
        let normalised = calendar.startOfMonth(prev)
        guard availableMonths.contains(normalised) else { return }
        currentMonth = normalised
    }

    public func goToNextMonth() {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return }
        let normalised = calendar.startOfMonth(next)
        guard availableMonths.contains(normalised) else { return }
        currentMonth = normalised
    }

    // MARK: - Month aggregates

    /// Every entry whose `createdAt` falls in the given month.
    public func entriesInMonth(_ month: Date) -> [EntrySnapshot] {
        let monthStart = calendar.startOfMonth(month)
        return entriesByDay
            .filter { (day, _) in calendar.isDate(day, equalTo: monthStart, toGranularity: .month) }
            .flatMap { $0.value }
    }

    /// Distinct number of days in the month that have at least one entry.
    public func activeDaysInMonth(_ month: Date) -> Int {
        let monthStart = calendar.startOfMonth(month)
        return entriesByDay.reduce(0) { acc, pair in
            let (day, entries) = pair
            guard !entries.isEmpty,
                  calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
            else { return acc }
            return acc + 1
        }
    }
}

public extension Calendar {
    func startOfMonth(_ date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
