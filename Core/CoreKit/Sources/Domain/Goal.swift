import Foundation

/// A tag-driven, count-toward-target goal. Like `Habit`, progress is
/// derived from existing entries — no parallel logging. Optional
/// deadline supports both bounded ("100 entries by year-end") and
/// open-ended ("just keep going") goals.
///
/// Pro feature gated by `ProEntitlement.goalsAndHabits`.
public struct Goal: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var tag: String
    public var targetCount: Int
    /// Optional. When set, only entries created on or before the
    /// deadline contribute. When nil, the goal stays open until the
    /// user deletes or completes it.
    public var deadline: Date?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        tag: String,
        targetCount: Int,
        deadline: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.tag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.targetCount = max(1, targetCount)
        self.deadline = deadline
        self.createdAt = createdAt
    }
}
