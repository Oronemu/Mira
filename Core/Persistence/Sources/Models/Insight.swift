import Foundation
import SwiftData

public enum InsightType: String, Codable, Sendable {
    case weekly
    case monthly
    case askMira
    case pattern
}

@Model
public final class Insight {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var typeRaw: String
    public var title: String
    public var content: String
    public var relatedEntryIDs: [UUID]
    public var provider: String

    public var type: InsightType {
        get { InsightType(rawValue: typeRaw) ?? .pattern }
        set { typeRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        type: InsightType,
        title: String,
        content: String,
        relatedEntryIDs: [UUID] = [],
        provider: String = "unknown"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.typeRaw = type.rawValue
        self.title = title
        self.content = content
        self.relatedEntryIDs = relatedEntryIDs
        self.provider = provider
    }
}
