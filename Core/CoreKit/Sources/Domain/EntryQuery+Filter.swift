import Foundation

public extension EntryQuery {
    /// Apply this query's filters / sort / limit to a list of snapshots.
    /// Used by mock and SwiftData repositories that load eagerly and filter
    /// in memory. SwiftData predicates can pre-filter before invoking this
    /// helper once query volume justifies it.
    func apply(to snapshots: [EntrySnapshot]) -> [EntrySnapshot] {
        var result = snapshots
        if let text, !text.isEmpty {
            result = result.filter { $0.plainContent.localizedCaseInsensitiveContains(text) }
        }
        if let dateRange {
            result = result.filter { dateRange.contains($0.createdAt) }
        }
        if let moods {
            result = result.filter { entry in entry.mood.map { moods.contains($0) } ?? false }
        }
        if let tags, !tags.isEmpty {
            let want = Set(tags)
            result = result.filter { !Set($0.tags).isDisjoint(with: want) }
        }
        switch sortBy {
        case .createdAtDescending: result.sort { $0.createdAt > $1.createdAt }
        case .createdAtAscending: result.sort { $0.createdAt < $1.createdAt }
        case .updatedAtDescending: result.sort { $0.updatedAt > $1.updatedAt }
        }
        if let limit { result = Array(result.prefix(limit)) }
        return result
    }
}
