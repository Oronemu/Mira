import Foundation
import CoreKit

extension AskMiraChat {
    func snapshot() -> AskMiraChatSnapshot {
        let sorted = turns.sorted { $0.createdAt < $1.createdAt }
        let preview = sorted.last.map { "\($0.question)" }
        return AskMiraChatSnapshot(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            turnCount: turns.count,
            lastMessagePreview: preview
        )
    }
}
