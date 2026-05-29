import Foundation
import CoreKit

/// In-memory PNG cache shared by every `StickerImage` that renders a
/// `"user:<uuid>"` libraryRef. Stickers can appear many times across an
/// entry's overlay and across rows in the picker — hitting disk on each
/// mount would produce visible flashes when scrolling. The cache is
/// process-local, dropped on launch.
///
/// Invalidation is best-effort: `invalidate(id:)` is called by the
/// picker after delete, and a fresh save under the same id (e.g. from
/// the sync puller materialising a remote copy) writes through here on
/// next read since lookups miss when keys are absent.
public actor CustomStickerByteCache {
    public static let shared = CustomStickerByteCache()

    private var entries: [UUID: Data] = [:]

    public init() {}

    public func data(
        for id: UUID,
        relativePath: String,
        loader: any CustomStickerStoring
    ) async -> Data? {
        if let cached = entries[id] {
            return cached
        }
        do {
            let bytes = try await loader.read(relativePath: relativePath)
            entries[id] = bytes
            return bytes
        } catch {
            return nil
        }
    }

    public func invalidate(id: UUID) {
        entries.removeValue(forKey: id)
    }

    public func invalidateAll() {
        entries.removeAll()
    }
}
