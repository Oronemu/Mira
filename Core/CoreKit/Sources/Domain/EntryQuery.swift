import Foundation

/// Filter / sort criteria for fetching entries via `EntryRepository`.
public struct EntryQuery: Sendable, Hashable {
    public enum SortField: Sendable, Hashable {
        case createdAtDescending
        case createdAtAscending
        case updatedAtDescending
    }

    public var text: String?
    public var dateRange: ClosedRange<Date>?
    public var moods: Set<Mood>?
    public var tags: [String]?
    public var sortBy: SortField
    public var limit: Int?

    public init(
        text: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        moods: Set<Mood>? = nil,
        tags: [String]? = nil,
        sortBy: SortField = .createdAtDescending,
        limit: Int? = nil
    ) {
        self.text = text
        self.dateRange = dateRange
        self.moods = moods
        self.tags = tags
        self.sortBy = sortBy
        self.limit = limit
    }

    public static let all = EntryQuery()
}
