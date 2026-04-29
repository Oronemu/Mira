import Foundation

/// Per-row change event emitted by `EntryRepository.changes()`. The sync
/// pusher subscribes to this stream to decide what to upload; the UI
/// layer continues to use `observe(query:)` which yields the full
/// filtered collection.
public enum EntryChange: Sendable, Hashable {
    case upserted(EntrySnapshot)
    case deleted(UUID)

    public var id: UUID {
        switch self {
        case .upserted(let snapshot): snapshot.id
        case .deleted(let id): id
        }
    }
}
