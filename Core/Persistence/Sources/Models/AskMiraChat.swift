import Foundation
import SwiftData

@Model
public final class AskMiraChat {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var title: String

    @Relationship(deleteRule: .cascade, inverse: \AskMiraTurn.chat)
    public var turns: [AskMiraTurn] = []

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
    }
}
