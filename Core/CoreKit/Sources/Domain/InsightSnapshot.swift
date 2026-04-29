import Foundation

/// Immutable, Sendable view of an AI-generated insight (e.g. weekly reflection).
public struct InsightSnapshot: Sendable, Hashable, Identifiable, Codable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case weeklyReflection
        case monthlyReflection
        case askMiraAnswer
    }

    public let id: UUID
    public let createdAt: Date
    public let kind: Kind
    public let title: String
    public let body: String
    public let referencedEntryIDs: [UUID]

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        kind: Kind,
        title: String,
        body: String,
        referencedEntryIDs: [UUID] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.title = title
        self.body = body
        self.referencedEntryIDs = referencedEntryIDs
    }
}
