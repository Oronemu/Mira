import Foundation

/// Per-asset change event emitted by `CustomStickerStoring.changes()`.
/// Same shape as `EntryChange` / `InsightChange` so the sync pusher can
/// observe sticker creates and deletes through a uniform stream.
public enum CustomStickerChange: Sendable, Hashable {
    case upserted(CustomStickerAsset)
    case deleted(UUID)

    public var id: UUID {
        switch self {
        case .upserted(let asset): asset.id
        case .deleted(let id): id
        }
    }
}
