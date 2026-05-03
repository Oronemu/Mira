import Foundation

/// User-named persisted slice of `EntryQuery` — a "smart filter" the
/// EntryList can apply with one tap. Only carries the dimensions the
/// filter sheet exposes (date range, moods, tags); search text and
/// sort order stay live properties of the list itself rather than
/// frozen into the saved shape.
///
/// Pro feature gated by `ProEntitlement.smartFilters`.
public struct SavedFilter: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var dateRange: ClosedRange<Date>?
    /// Mood `rawValue`s. Stored as `Int` rather than `Mood` so a future
    /// scale change wouldn't invalidate persisted filters.
    public var moods: Set<Int>
    public var tags: [String]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        dateRange: ClosedRange<Date>? = nil,
        moods: Set<Int> = [],
        tags: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.dateRange = dateRange
        self.moods = moods
        self.tags = tags
        self.createdAt = createdAt
    }

    /// `true` when at least one criterion is set — empty filters are
    /// pointless to save and the UI hides the save action for them.
    public var hasCriteria: Bool {
        dateRange != nil || !moods.isEmpty || !tags.isEmpty
    }

    public func makeQuery(text: String? = nil) -> EntryQuery {
        EntryQuery(
            text: text,
            dateRange: dateRange,
            moods: moods.isEmpty ? nil : Set(moods.compactMap { Mood(rawValue: $0) }),
            tags: tags.isEmpty ? nil : tags
        )
    }

    public init(name: String, from query: EntryQuery) {
        self.init(
            name: name,
            dateRange: query.dateRange,
            moods: Set((query.moods ?? []).map(\.rawValue)),
            tags: query.tags ?? []
        )
    }
}
