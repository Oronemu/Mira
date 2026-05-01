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

    // MARK: - Selection
    public private(set) var isSelectionMode: Bool = false
    public private(set) var selection: Set<UUID> = []

    private var allEntries: [EntrySnapshot] = []
    private let repository: any EntryRepository
    private let analyticsService: any AnalyticsService
    private let crashReporter: any CrashReporter

    public init(
        repository: any EntryRepository,
        initialQuery: EntryQuery = .all,
        analyticsService: any AnalyticsService = UnimplementedAnalyticsService(),
        crashReporter: any CrashReporter = UnimplementedCrashReporter()
    ) {
        self.repository = repository
        self.query = initialQuery
        self.analyticsService = analyticsService
        self.crashReporter = crashReporter
    }

    /// Long-running observation. Drive from the View's `.task` modifier
    /// so SwiftUI cancels it on disappear.
    public func observe() async {
        for await snapshot in repository.observe(query: .all) {
            allEntries = snapshot
            isLoading = false
            regroup()
            // Drop selection IDs that no longer exist (e.g. removed via
            // sync). Filtering changes preserve selection — iOS Mail does
            // the same when you switch mailboxes mid-edit.
            let alive = Set(snapshot.map(\.id))
            selection.formIntersection(alive)
        }
    }

    public func delete(id: UUID) async {
        do {
            try await repository.delete(id: id)
            analyticsService.log(event: "entry_deleted", parameters: ["source": .string("list")])
        } catch {
            errorMessage = error.localizedDescription
            crashReporter.recordError(error, reason: "entry_list.delete")
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

    // MARK: - Selection API

    public func enterSelection(with id: UUID? = nil) {
        isSelectionMode = true
        if let id { selection.insert(id) }
    }

    public func exitSelection() {
        isSelectionMode = false
        selection.removeAll()
    }

    public func toggle(id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    public func selectAllVisible() {
        selection = Set(visibleIDs)
    }

    public func deselectAll() {
        selection.removeAll()
    }

    public var selectionCount: Int { selection.count }

    public var allVisibleSelected: Bool {
        let visible = visibleIDs
        guard !visible.isEmpty else { return false }
        return visible.allSatisfy(selection.contains)
    }

    /// Deletes every selected entry in parallel and exits selection mode.
    /// Partial failures don't roll anything back — the last error wins
    /// `errorMessage` so the user sees something instead of silence.
    public func deleteSelected() async {
        let ids = selection
        guard !ids.isEmpty else { return }
        let count = ids.count
        await withTaskGroup(of: Error?.self) { group in
            for id in ids {
                group.addTask { [repository] in
                    do {
                        try await repository.delete(id: id)
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            for await error in group {
                if let error {
                    errorMessage = error.localizedDescription
                    crashReporter.recordError(error, reason: "entry_list.bulk_delete")
                }
            }
        }
        analyticsService.log(
            event: "entries_bulk_deleted",
            parameters: ["count": .int(count)]
        )
        selection.removeAll()
        isSelectionMode = false
    }

    // MARK: - Internals

    private var visibleIDs: [UUID] {
        sections.flatMap { $0.entries.map(\.id) }
    }

    private func regroup() {
        sections = query.apply(to: allEntries).groupedByMonth()
    }
}
