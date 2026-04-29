import Foundation
import Observation
import CoreKit

@MainActor
@Observable
public final class EntryListState {
    /// Mutating this re-derives `sections` from the cached entries snapshot.
    public var query: EntryQuery {
        didSet { regroup() }
    }

    public private(set) var sections: [EntryMonthSection] = []
    public private(set) var isLoading: Bool = true
    public private(set) var errorMessage: String?

    private var allEntries: [EntrySnapshot] = []
    private let repository: any EntryRepository

    public init(repository: any EntryRepository, initialQuery: EntryQuery = .all) {
        self.repository = repository
        self.query = initialQuery
    }

    /// Long-running observation. Drive from the View's `.task` modifier
    /// so SwiftUI cancels it on disappear.
    public func observe() async {
        for await snapshot in repository.observe(query: .all) {
            allEntries = snapshot
            isLoading = false
            regroup()
        }
    }

    public func delete(id: UUID) async {
        do {
            try await repository.delete(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Apply a free-text term to the active query without losing other filters.
    public func updateSearchText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var next = query
        next.text = trimmed.isEmpty ? nil : trimmed
        query = next
    }

    /// True when the active query narrows results in any dimension.
    public var hasActiveFilters: Bool {
        query.dateRange != nil
            || (query.moods?.isEmpty == false)
            || (query.tags?.isEmpty == false)
    }

    private func regroup() {
        sections = query.apply(to: allEntries).groupedByMonth()
    }
}
