import Foundation
import CoreKit

extension Insight {
    func snapshot() -> InsightSnapshot {
        InsightSnapshot(
            id: id,
            createdAt: createdAt,
            kind: type.snapshotKind,
            title: title,
            body: content,
            referencedEntryIDs: relatedEntryIDs
        )
    }
}

private extension InsightType {
    var snapshotKind: InsightSnapshot.Kind {
        switch self {
        case .weekly: .weeklyReflection
        case .monthly: .monthlyReflection
        case .askMira: .askMiraAnswer
        case .pattern: .weeklyReflection
        }
    }
}
