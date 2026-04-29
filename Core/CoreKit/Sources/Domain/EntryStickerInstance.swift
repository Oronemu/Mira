import Foundation
import CoreGraphics

/// A single decorative sticker placed on an entry's canvas. Free-floating —
/// stickers do not flow with text. Persisted as part of the entry's snapshot
/// (see `EntryStickersCodec`).
///
/// Coordinate model:
/// - `normalizedX` is `0…1` of the canvas width — keeps stickers visually
///   anchored across screen widths (rotation, larger devices).
/// - `y` is absolute points from the top of the editing canvas — stickers
///   stay pinned to the page even as text grows above them.
/// - `scale` is `1.0` at the renderer's base size (typically 64pt). Clamped
///   in UI to `Self.scaleRange`.
/// - `rotation` is radians, normalised to `(-π, π]`.
/// - `zIndex` orders stickers within the overlay; higher = closer to user.
public struct EntryStickerInstance: Sendable, Hashable, Identifiable, Codable {
    public static let scaleRange: ClosedRange<CGFloat> = 0.4...3.0

    public let id: UUID
    public let libraryRef: String
    public var normalizedX: CGFloat
    public var y: CGFloat
    public var scale: CGFloat
    public var rotation: CGFloat
    public var zIndex: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        libraryRef: String,
        normalizedX: CGFloat,
        y: CGFloat,
        scale: CGFloat = 1.0,
        rotation: CGFloat = 0,
        zIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.libraryRef = libraryRef
        self.normalizedX = normalizedX
        self.y = y
        self.scale = Self.clampScale(scale)
        self.rotation = Self.normaliseRotation(rotation)
        self.zIndex = zIndex
        self.createdAt = createdAt
    }

    // MARK: - Mutation helpers

    /// Returns a copy with the given transform applied. Scale is clamped and
    /// rotation is normalised so callers don't have to remember the rules.
    public func with(
        normalizedX: CGFloat? = nil,
        y: CGFloat? = nil,
        scale: CGFloat? = nil,
        rotation: CGFloat? = nil,
        zIndex: Int? = nil
    ) -> EntryStickerInstance {
        EntryStickerInstance(
            id: id,
            libraryRef: libraryRef,
            normalizedX: normalizedX ?? self.normalizedX,
            y: y ?? self.y,
            scale: scale ?? self.scale,
            rotation: rotation ?? self.rotation,
            zIndex: zIndex ?? self.zIndex,
            createdAt: createdAt
        )
    }

    public static func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, scaleRange.lowerBound), scaleRange.upperBound)
    }

    /// Normalises any rotation angle into the canonical `(-π, π]` range so
    /// stored data stays compact and equality is meaningful.
    public static func normaliseRotation(_ radians: CGFloat) -> CGFloat {
        let twoPi = 2 * CGFloat.pi
        var r = radians.truncatingRemainder(dividingBy: twoPi)
        if r > .pi { r -= twoPi }
        if r <= -.pi { r += twoPi }
        return r
    }
}

// MARK: - Codec

/// JSON-array codec for the sticker collection persisted on an entry.
/// Storing a single `Data` blob (rather than a SwiftData relationship) keeps
/// the migration trivial: existing entries simply have `nil` and decode to
/// an empty array.
public enum EntryStickersCodec {
    public static func encode(_ stickers: [EntryStickerInstance]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Default `.deferredToDate` strategy encodes Date as a Double timestamp
        // — preserves microsecond precision so round-trip equality holds.
        return try encoder.encode(stickers)
    }

    public static func decode(_ data: Data) throws -> [EntryStickerInstance] {
        let decoder = JSONDecoder()
        return try decoder.decode([EntryStickerInstance].self, from: data)
    }
}
