import Foundation
import CoreKit

public extension EntrySnapshot {
    static func sample(
        id: UUID = UUID(),
        createdAt: Date = .now,
        content: String = "Sample entry — quiet morning with coffee.",
        mood: Mood? = .good,
        tags: [String] = ["morning"]
    ) -> EntrySnapshot {
        EntrySnapshot(
            id: id,
            createdAt: createdAt,
            updatedAt: createdAt,
            plainContent: content,
            mood: mood,
            tags: tags
        )
    }
}
