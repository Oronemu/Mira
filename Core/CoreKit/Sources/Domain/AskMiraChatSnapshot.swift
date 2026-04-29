import Foundation

/// A single conversation with Mira. Groups a sequence of
/// `AskMiraTurnSnapshot`s that share context with each other.
///
/// `turnCount` and `lastMessagePreview` are denormalised projections the
/// repository fills in so list views can render without loading turns.
public struct AskMiraChatSnapshot: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let updatedAt: Date
    public let title: String
    public let turnCount: Int
    public let lastMessagePreview: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String,
        turnCount: Int = 0,
        lastMessagePreview: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.turnCount = turnCount
        self.lastMessagePreview = lastMessagePreview
    }
}
