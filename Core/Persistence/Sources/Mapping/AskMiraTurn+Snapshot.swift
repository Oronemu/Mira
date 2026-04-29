import Foundation
import CoreKit

extension AskMiraTurn {
    func snapshot() -> AskMiraTurnSnapshot {
        AskMiraTurnSnapshot(
            id: id,
            createdAt: createdAt,
            question: question,
            answer: answer,
            referencedEntryIDs: referencedEntryIDs
        )
    }
}
