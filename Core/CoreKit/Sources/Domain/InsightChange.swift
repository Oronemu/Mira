import Foundation

/// Per-row change event emitted by `InsightRepository.changes()`.
public enum InsightChange: Sendable, Hashable {
    case upserted(InsightSnapshot)
    case deleted(UUID)

    public var id: UUID {
        switch self {
        case .upserted(let snapshot): snapshot.id
        case .deleted(let id): id
        }
    }
}
