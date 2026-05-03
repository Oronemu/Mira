import Foundation

/// A tag-driven habit. Progress is *fully derived* from existing
/// entries — there's no separate "log habit" action. The user marks a
/// habit done by tagging an entry with `tag`. Cadence determines the
/// rolling window the calculator counts in.
///
/// Pro feature gated by `ProEntitlement.goalsAndHabits`.
public struct Habit: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public var name: String
    /// Lowercase tag string the entries should carry to count toward
    /// this habit. Stored normalised so picker / matcher don't have to
    /// re-normalise on every read.
    public var tag: String
    public var cadence: Cadence
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        tag: String,
        cadence: Cadence,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.tag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.cadence = cadence
        self.createdAt = createdAt
    }

    public enum Cadence: Sendable, Hashable, Codable {
        /// One occurrence per day; progress is the current consecutive-day
        /// streak.
        case daily
        /// X occurrences within the current calendar week.
        case weekly(target: Int)
        /// X occurrences within the current calendar month.
        case monthly(target: Int)
    }
}
