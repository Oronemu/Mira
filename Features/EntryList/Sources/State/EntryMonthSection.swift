import Foundation
import CoreKit

/// One month worth of entries, used as the primary section model in the list.
public struct EntryMonthSection: Identifiable, Hashable, Sendable {
    /// Stable id like "2026-04" — also used for descending sort.
    public let id: String
    /// Localised display title, e.g. "April 2026".
    public let title: String
    public let entries: [EntrySnapshot]

    public init(id: String, title: String, entries: [EntrySnapshot]) {
        self.id = id
        self.title = title
        self.entries = entries
    }
}

public extension Array where Element == EntrySnapshot {
    /// Group by year-month, sort sections newest-first, sort entries
    /// within each section newest-first.
    func groupedByMonth(calendar: Calendar = .current, locale: Locale = .current) -> [EntryMonthSection] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL yyyy"

        let groups = Dictionary(grouping: self) { entry -> String in
            let comps = calendar.dateComponents([.year, .month], from: entry.createdAt)
            return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        }

        return groups
            .sorted { $0.key > $1.key }
            .map { key, entries in
                let representative = entries.first?.createdAt ?? .now
                return EntryMonthSection(
                    id: key,
                    title: formatter.string(from: representative).capitalized,
                    entries: entries.sorted { $0.createdAt > $1.createdAt }
                )
            }
    }
}
