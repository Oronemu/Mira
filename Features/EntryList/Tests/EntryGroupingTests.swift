import Foundation
import Testing
@testable import FeatureEntryList
import CoreKit

@Suite("EntryMonthSection grouping")
struct EntryGroupingTests {
    @Test("groups sort newest month first")
    func groupSorting() {
        let calendar = Calendar(identifier: .gregorian)
        let jan = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let feb = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!
        let entries = [
            EntrySnapshot(createdAt: jan, content: "jan"),
            EntrySnapshot(createdAt: feb, content: "feb"),
        ]

        let sections = entries.groupedByMonth(calendar: calendar, locale: Locale(identifier: "en_US"))

        #expect(sections.count == 2)
        #expect(sections[0].id == "2026-02")
        #expect(sections[1].id == "2026-01")
    }

    @Test("entries inside a section sort newest first")
    func entrySortingWithinSection() {
        let calendar = Calendar(identifier: .gregorian)
        let early = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let late = calendar.date(from: DateComponents(year: 2026, month: 4, day: 28))!
        let entries = [
            EntrySnapshot(createdAt: early, content: "early"),
            EntrySnapshot(createdAt: late, content: "late"),
        ]

        let section = entries.groupedByMonth(calendar: calendar).first!

        #expect(section.entries.first?.content == "late")
        #expect(section.entries.last?.content == "early")
    }

    @Test("empty input produces empty sections")
    func emptyInput() {
        #expect([EntrySnapshot]().groupedByMonth().isEmpty)
    }
}
