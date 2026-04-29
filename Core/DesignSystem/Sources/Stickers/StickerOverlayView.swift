import SwiftUI
import CoreKit

/// Free-floating sticker layer that sits above the entry's text editor.
/// Owns geometry-aware placement (normalised X × absolute Y → on-screen
/// point) and stable z-ordering. Per-sticker manipulation lives in
/// `StickerInstanceView`; this view is the placement coordinator.
///
/// Read mode (`interactive == false`) renders the same layout but skips
/// gestures, selection chrome, and drop handling, so the same view drives
/// both EntryEditor canvases and EntryDetail's reading view.
public struct StickerOverlayView: View {
    /// Public anchor for the canvas's named coordinate space — both the
    /// host (drop destination, geometry tracking) and the sticker's
    /// rotate-handle drag read finger position from here so they all
    /// agree on what "(x, y)" means.
    public static let canvasCoordinateSpace: NamedCoordinateSpace = .named("StickerCanvas")

    private let stickers: [EntryStickerInstance]
    @Binding private var selectedID: UUID?
    private let interactive: Bool
    private let onUpdate: (EntryStickerInstance) -> Void
    private let onRemove: (UUID) -> Void
    private let onDuplicate: (UUID) -> Void
    private let onBringForward: (UUID) -> Void
    private let onSendBackward: (UUID) -> Void
    private let onManipulatingChange: (Bool) -> Void

    public init(
        stickers: [EntryStickerInstance],
        selectedID: Binding<UUID?>,
        interactive: Bool,
        onUpdate: @escaping (EntryStickerInstance) -> Void,
        onRemove: @escaping (UUID) -> Void,
        onDuplicate: @escaping (UUID) -> Void = { _ in },
        onBringForward: @escaping (UUID) -> Void = { _ in },
        onSendBackward: @escaping (UUID) -> Void = { _ in },
        onManipulatingChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.stickers = stickers
        self._selectedID = selectedID
        self.interactive = interactive
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        self.onDuplicate = onDuplicate
        self.onBringForward = onBringForward
        self.onSendBackward = onSendBackward
        self.onManipulatingChange = onManipulatingChange
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                // Transparent backing — passes touches through to whatever
                // is below (TextEditor) on empty areas. Without it the
                // GeometryReader would still hit-test on empty space.
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)

                ForEach(orderedStickers) { sticker in
                    StickerInstanceView(
                        instance: sticker,
                        isSelected: interactive && selectedID == sticker.id,
                        canvasSize: proxy.size,
                        interactive: interactive,
                        onTap: { selectedID = sticker.id },
                        onUpdate: { onUpdate($0) },
                        onRemove: { onRemove(sticker.id) },
                        onDuplicate: { onDuplicate(sticker.id) },
                        onBringForward: { onBringForward(sticker.id) },
                        onSendBackward: { onSendBackward(sticker.id) },
                        onManipulatingChange: onManipulatingChange
                    )
                    .zIndex(Double(sticker.zIndex))
                }
            }
            // Named space lets the rotate handle's drag gesture read
            // finger position in the same canvas coordinates that
            // `instance.normalizedX × y` resolve into.
            .coordinateSpace(Self.canvasCoordinateSpace)
        }
    }

    /// Stable draw order — by zIndex ascending so higher zIndex renders on
    /// top. Tie-break by createdAt to keep deterministic ordering when two
    /// stickers share an index.
    private var orderedStickers: [EntryStickerInstance] {
        stickers.sorted { lhs, rhs in
            if lhs.zIndex != rhs.zIndex { return lhs.zIndex < rhs.zIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
