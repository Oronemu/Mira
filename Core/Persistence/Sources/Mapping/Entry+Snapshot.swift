import Foundation
import CoreKit

extension Entry {
    func snapshot() -> EntrySnapshot {
        EntrySnapshot(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            content: resolvedContent(),
            mood: mood.flatMap(Mood.init(rawValue:)),
            tags: tags,
            photos: photos
                .sorted { $0.createdAt < $1.createdAt }
                .map { PhotoAssetSnapshot(id: $0.id, relativePath: $0.relativePath, createdAt: $0.createdAt) },
            stickers: resolvedStickers()
        )
    }

    private func resolvedStickers() -> [EntryStickerInstance] {
        guard let data = stickersData, !data.isEmpty else { return [] }
        return (try? EntryStickersCodec.decode(data)) ?? []
    }

    /// Resolves the stored body into an `AttributedString`. Prefers
    /// `contentData` (new rich-text rollout); falls back to reconstructing
    /// an attributed string from plain `content` + legacy per-entry style
    /// fields so existing records visually retain their chosen style.
    private func resolvedContent() -> AttributedString {
        if let data = contentData,
           let decoded = try? EntryContentCodec.decode(data) {
            return decoded
        }
        let legacy = EntryTextStyle(
            size: EntryFontSize(rawValue: fontSizeLevel) ?? .regular,
            family: EntryFontFamily(rawValue: fontFamilyRaw) ?? .serif,
            color: EntryTextColor(storageString: textColorSpec) ?? .preset(.default)
        )
        return EntryContentCodec.attributedString(from: content, applying: legacy)
    }
}
