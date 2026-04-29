import Foundation
import CoreKit

/// Generates periodic reflection Insights by summarising recent journal
/// entries through the configured AI provider. Pure orchestration — no
/// persistence of its own beyond writing the finished Insight.
public struct ReflectionService: Sendable {
    public enum Period: Sendable, Hashable {
        case lastDays(Int)

        var days: Int {
            switch self {
            case .lastDays(let value): value
            }
        }
    }

    public init() {}

    /// Collects entries in the period, asks the AI for a reflection, and
    /// persists it as an Insight. Returns the saved snapshot, or nil if
    /// there were no entries in the window.
    @discardableResult
    public func generate(
        period: Period = .lastDays(7),
        asOf date: Date = .now,
        kind: InsightSnapshot.Kind = .weeklyReflection,
        locale: Locale = .autoupdatingCurrent,
        aiProvider: any AIProvider,
        entryRepository: any EntryRepository,
        insightRepository: any InsightRepository,
        calendar: Calendar = .current
    ) async throws -> InsightSnapshot? {
        let range = Self.range(ending: date, days: period.days, calendar: calendar)
        let entries = try await fetchEntries(in: range, repository: entryRepository)
        guard !entries.isEmpty else { return nil }

        let request = PromptTemplates.weeklyReflection(entries: entries, locale: locale)
        let answer = try await run(request: request, using: aiProvider)
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.requestFailed("Empty reflection") }

        let insight = InsightSnapshot(
            createdAt: date,
            kind: kind,
            title: Self.title(for: range, locale: locale),
            body: trimmed,
            referencedEntryIDs: entries.map(\.id)
        )
        try await insightRepository.save(insight)
        return insight
    }

    private func fetchEntries(
        in range: ClosedRange<Date>,
        repository: any EntryRepository
    ) async throws -> [EntrySnapshot] {
        var query = EntryQuery.all
        query.dateRange = range
        return try await repository.fetch(matching: query)
    }

    private func run(request: AIRequest, using provider: any AIProvider) async throws -> String {
        var accumulated = ""
        let stream = try await provider.stream(request)
        for try await chunk in stream {
            accumulated += chunk.textDelta
            if chunk.isFinal { break }
        }
        return accumulated
    }

    static func range(ending date: Date, days: Int, calendar: Calendar) -> ClosedRange<Date> {
        let end = date
        let startOfEnd = calendar.startOfDay(for: end)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfEnd) ?? startOfEnd
        return start...end
    }

    static func title(for range: ClosedRange<Date>, locale: Locale) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: range.lowerBound, to: range.upperBound)
    }
}
