import Foundation
import Testing
@testable import CoreKit

@Suite("EntryStickerInstance")
struct EntryStickerInstanceTests {
    @Test("scale clamps into the canonical range")
    func scaleClamps() {
        let s = EntryStickerInstance(libraryRef: "phosphor:leaf", normalizedX: 0.5, y: 100, scale: 9.5)
        #expect(s.scale == EntryStickerInstance.scaleRange.upperBound)

        let tiny = s.with(scale: -1)
        #expect(tiny.scale == EntryStickerInstance.scaleRange.lowerBound)
    }

    @Test("rotation normalises into (-π, π]")
    func rotationNormalises() {
        let twoPi = EntryStickerInstance.normaliseRotation(2 * .pi + 0.01)
        #expect(abs(twoPi - 0.01) < 1e-9)

        let bigNeg = EntryStickerInstance.normaliseRotation(-3 * .pi)
        #expect(abs(bigNeg - .pi) < 1e-9)

        let stable = EntryStickerInstance.normaliseRotation(.pi / 4)
        #expect(abs(stable - .pi / 4) < 1e-9)
    }

    @Test("with(...) preserves identity and timestamp")
    func withPreservesIdentity() {
        let original = EntryStickerInstance(
            libraryRef: "phosphor:heart",
            normalizedX: 0.4,
            y: 80,
            scale: 1.2,
            rotation: 0.2,
            zIndex: 3
        )
        let updated = original.with(normalizedX: 0.7, scale: 2)
        #expect(updated.id == original.id)
        #expect(updated.libraryRef == original.libraryRef)
        #expect(updated.createdAt == original.createdAt)
        #expect(updated.normalizedX == 0.7)
        #expect(updated.scale == 2.0)
        // Untouched fields stay put.
        #expect(updated.rotation == original.rotation)
        #expect(updated.y == original.y)
        #expect(updated.zIndex == original.zIndex)
    }

    @Test("EntryStickersCodec round-trips a non-empty collection")
    func codecRoundTrip() throws {
        let stickers = [
            EntryStickerInstance(libraryRef: "phosphor:leaf", normalizedX: 0.2, y: 40),
            EntryStickerInstance(libraryRef: "phosphor:heart", normalizedX: 0.8, y: 200, scale: 1.6, rotation: 0.5, zIndex: 2),
        ]
        let data = try EntryStickersCodec.encode(stickers)
        let decoded = try EntryStickersCodec.decode(data)
        #expect(decoded == stickers)
    }

    @Test("EntryStickersCodec round-trips an empty collection")
    func codecEmpty() throws {
        let data = try EntryStickersCodec.encode([])
        let decoded = try EntryStickersCodec.decode(data)
        #expect(decoded.isEmpty)
    }

    @Test("EntrySnapshot Codable carries stickers when non-empty")
    func snapshotCodableWithStickers() throws {
        let stickers = [
            EntryStickerInstance(libraryRef: "phosphor:leaf", normalizedX: 0.3, y: 64)
        ]
        let original = EntrySnapshot(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500),
            content: "today",
            stickers: stickers
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EntrySnapshot.self, from: data)
        #expect(decoded.stickers == stickers)
    }

    @Test("EntrySnapshot Codable defaults stickers to [] when key missing")
    func snapshotCodableWithoutStickers() throws {
        // Encode a snapshot with no stickers — the encoder omits the key,
        // so this also exercises the "old payload" decode path.
        let original = EntrySnapshot(content: "without")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EntrySnapshot.self, from: data)
        #expect(decoded.stickers.isEmpty)
    }
}
