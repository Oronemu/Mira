import SwiftUI
import CoreKit

/// One placed sticker. Renders the artwork, applies the persisted
/// transform, and — when selected and interactive — exposes a dashed
/// selection ring plus two corner handles: a red X in the top-leading
/// for delete, and a retry-arrow in the top-trailing that drives
/// single-finger rotate + scale.
///
/// Layout: the chrome handles are *siblings* of the StickerImage in a
/// ZStack, not overlays on it. That matters for hit-testing: an overlay
/// positioned outside its parent's frame routes touches through the
/// parent's gesture stack first; a sibling at the same depth is
/// routed independently. With this structure each handle's
/// `.highPriorityGesture` reliably wins over the body's gesture for
/// touches that start on it.
///
/// In-flight gesture deltas live in `@GestureState`, which SwiftUI
/// auto-resets to identity the instant the gesture ends, so the
/// committed transform on `instance` and the cleared delta arrive in
/// the same render pass — no flicker. Drag's `onChanged`/`onEnded`
/// surface a manipulation flag through `onManipulatingChange` so the
/// host can disable the outer ScrollView while a sticker is being
/// moved (otherwise SwiftUI's ScrollView pan competes with the drag
/// and the sticker oscillates).
struct StickerInstanceView: View {
    /// Renderer base size in points — `scale == 1.0` maps here.
    static let baseSize: CGFloat = 64
    /// Visible padding between the dashed ring and a corner handle.
    private static let chromeOverhang: CGFloat = 6

    let instance: EntryStickerInstance
    let isSelected: Bool
    let canvasSize: CGSize
    let interactive: Bool
    let onTap: () -> Void
    let onUpdate: (EntryStickerInstance) -> Void
    let onRemove: () -> Void
    let onDuplicate: () -> Void
    let onBringForward: () -> Void
    let onSendBackward: () -> Void
    /// Fires `true` when any manipulation gesture (body drag, pinch,
    /// rotate, or corner-handle drag) starts; `false` when it ends.
    /// The host uses this to toggle `.scrollDisabled(_:)` on the outer
    /// ScrollView so it stops competing with the sticker drag.
    var onManipulatingChange: (Bool) -> Void = { _ in }

    private struct LiveDelta: Equatable {
        var translation: CGSize = .zero
        var scaleFactor: CGFloat = 1.0
        var rotation: Angle = .zero
    }

    @GestureState private var bodyDelta = LiveDelta()
    @GestureState private var handleDelta = LiveDelta()

    private var liveScale: CGFloat {
        EntryStickerInstance.clampScale(
            instance.scale * bodyDelta.scaleFactor * handleDelta.scaleFactor
        )
    }

    private var liveRotation: Angle {
        .radians(instance.rotation) + bodyDelta.rotation + handleDelta.rotation
    }

    private var basePosition: CGPoint {
        CGPoint(
            x: max(0, canvasSize.width) * instance.normalizedX,
            y: instance.y
        )
    }

    private var livePosition: CGPoint {
        CGPoint(
            x: basePosition.x + bodyDelta.translation.width,
            y: basePosition.y + bodyDelta.translation.height
        )
    }

    /// 1 / liveScale — chrome strokes / sizes / offsets multiply by this
    /// so the visible chrome stays constant regardless of sticker scale.
    private var chromeCompensation: CGFloat {
        1.0 / max(liveScale, 0.01)
    }

    var body: some View {
        stickerWithMenu
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityActions {
                if interactive {
                    Button(String(localized: "Delete"), role: .destructive) { onRemove() }
                    Button(String(localized: "Duplicate")) { onDuplicate() }
                    Button(String(localized: "Bring forward")) { onBringForward() }
                    Button(String(localized: "Send backward")) { onSendBackward() }
                }
            }
            .position(livePosition)
            // Animate ONLY the selection-chrome fade, never the live
            // transform — animating live transforms re-introduces the
            // rubber-band jitter on every gesture event.
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isSelected)
    }

    /// Visible side length at the committed scale. `scaleEffect` makes the
    /// sticker *look* this big but never grows its layout bounds (those stay
    /// `baseSize`). Anything that needs the real on-screen size — the
    /// context-menu source frame, the preview — uses this instead.
    private var committedSide: CGFloat {
        Self.baseSize * EntryStickerInstance.clampScale(instance.scale)
    }

    /// Approximate extent of the dashed selection ring beyond the sticker
    /// edge, per side, in screen points.
    private static let ringExtent: CGFloat = 10
    /// Source-frame margin: ring + the corner handles (badge + overhang),
    /// so the lifted snapshot doesn't clip the chrome of a selected sticker.
    private static let chromeExtent: CGFloat = 22

    /// Axis-aligned bounding side that fully contains a `committedSide`
    /// square — expanded by `extent` on every side — after it is rotated
    /// by the committed rotation. For a square of side `L` rotated by θ the
    /// bounding box side is `L·(|cos θ| + |sin θ|)`. Both the context-menu
    /// source frame and the preview size themselves with this so neither
    /// clips a rotated sticker or its dashed ring.
    private func rotatedBoundingSide(extent: CGFloat) -> CGFloat {
        let side = committedSide + extent * 2
        let r = instance.rotation
        return side * (abs(cos(r)) + abs(sin(r)))
    }

    /// Attaches the context menu only in interactive mode.
    ///
    /// The `.frame(rotatedBoundingSide…)` is what stops the "tiny square"
    /// flash. iOS lifts the menu's *source* view during the long-press and
    /// the dismiss animation, snapshotting it by its *layout* bounds — but
    /// `scaleEffect`/`rotationEffect` are geometry effects that never grow
    /// those bounds (they stay at the fixed `baseSize`). Sizing the frame to
    /// the rotated bounding box of the scaled sticker + chrome makes the
    /// snapshot match what's on screen, so a scaled-up or rotated sticker no
    /// longer flashes clipped. Committed `instance.scale`/`rotation` (not the
    /// live values) are used so the frame never re-lays-out mid-gesture — a
    /// long-press can't fire during an active pinch/drag anyway.
    @ViewBuilder
    private var stickerWithMenu: some View {
        if interactive {
            transformedSticker
                .frame(
                    width: rotatedBoundingSide(extent: Self.chromeExtent),
                    height: rotatedBoundingSide(extent: Self.chromeExtent)
                )
                .contextMenu {
                    contextMenuItems
                } preview: {
                    previewSticker
                }
        } else {
            transformedSticker
        }
    }

    /// Snapshot of the sticker for the floating menu platter — rendered at
    /// its real rotation (no selection chrome) and sized to the rotated
    /// bounding box so the artwork isn't clipped. Padded so the platter
    /// leaves a little breathing room around the artwork.
    private var previewSticker: some View {
        let side = rotatedBoundingSide(extent: Self.ringExtent)
        return StickerImage(libraryRef: instance.libraryRef, tone: .ink)
            .frame(width: committedSide, height: committedSide)
            .rotationEffect(.radians(Double(instance.rotation)))
            .frame(width: side, height: side)
            .padding(16)
    }

    /// The rendered sticker (with its scale + rotation transform) plus
    /// chrome handles as ZStack siblings. Handles aren't overlays:
    /// putting them at the same tree depth as the StickerImage keeps
    /// hit-testing routing independent so a tap on a handle reliably
    /// reaches its `.highPriorityGesture` instead of being absorbed by
    /// the body's gesture.
    private var transformedSticker: some View {
        ZStack {
            StickerImage(libraryRef: instance.libraryRef, tone: .ink)
                .frame(width: Self.baseSize, height: Self.baseSize)
                .background {
                    if isSelected { selectionRing }
                }
                .contentShape(.rect)
                .highPriorityGesture(combinedManipulation, including: interactive ? .all : .none)
                .onTapGesture {
                    guard interactive else { return }
                    onTap()
                }

            if isSelected && interactive {
                deleteHandle
                    .offset(
                        x: -(Self.baseSize / 2 + Self.chromeOverhang * chromeCompensation),
                        y: -(Self.baseSize / 2 + Self.chromeOverhang * chromeCompensation)
                    )
                rotateScaleHandle
                    .offset(
                        x: Self.baseSize / 2 + Self.chromeOverhang * chromeCompensation,
                        y: -(Self.baseSize / 2 + Self.chromeOverhang * chromeCompensation)
                    )
            }
        }
        .scaleEffect(liveScale)
        .rotationEffect(liveRotation)
    }

    // MARK: - Selection chrome

    private var selectionRing: some View {
        let s = chromeCompensation
        return RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
            .strokeBorder(
                MiraPalette.primaryText.opacity(0.55),
                style: StrokeStyle(
                    lineWidth: 1.4 * s,
                    lineCap: .round,
                    dash: [5 * s, 4 * s]
                )
            )
            .padding(-9 * s)
            .allowsHitTesting(false)
    }

    private var deleteHandle: some View {
        cornerBadge(
            systemImage: "xmark",
            tint: Color(.systemRed)
        )
        .scaleEffect(chromeCompensation)
        .contentShape(Circle())
        .highPriorityGesture(TapGesture().onEnded { onRemove() })
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(localized: "Delete sticker"))
    }

    private var rotateScaleHandle: some View {
        cornerBadge(
            systemImage: "arrow.triangle.2.circlepath",
            tint: MiraPalette.primaryText.opacity(0.85)
        )
        .scaleEffect(chromeCompensation)
        .contentShape(Circle())
        .highPriorityGesture(rotateScaleGesture)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(localized: "Rotate or resize sticker"))
    }

    private func cornerBadge(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 22, height: 22)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle().stroke(MiraPalette.divider, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 1)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            resetTransform()
        } label: {
            Label(
                String(localized: "Reset Size & Rotation"),
                systemImage: "arrow.counterclockwise"
            )
        }
        Button {
            onDuplicate()
        } label: {
            Label(String(localized: "Duplicate"), systemImage: "plus.square.on.square")
        }
        Button {
            onBringForward()
        } label: {
            Label(
                String(localized: "Bring Forward"),
                systemImage: "square.3.layers.3d.top.filled"
            )
        }
        Button {
            onSendBackward()
        } label: {
            Label(
                String(localized: "Send Backward"),
                systemImage: "square.3.layers.3d.bottom.filled"
            )
        }
        Divider()
        Button(role: .destructive) {
            onRemove()
        } label: {
            Label(String(localized: "Delete"), systemImage: "trash")
        }
    }

    // MARK: - Gestures

    private var combinedManipulation: some Gesture {
        // `coordinateSpace: canvas` is critical: `.scaleEffect` is applied
        // to the gesture-bearing view, so the default `.local` space
        // would report translation in the *scaled* view's units —
        // a big sticker would crawl while a small one would fly across
        // the screen. Reading translation in canvas coords gives a
        // 1:1 mapping between finger movement and sticker travel
        // regardless of scale.
        let drag = DragGesture(
            minimumDistance: 4,
            coordinateSpace: StickerOverlayView.canvasCoordinateSpace
        )
            .updating($bodyDelta) { value, state, _ in
                guard isSelected else { return }
                state.translation = value.translation
            }
            .onChanged { _ in
                guard isSelected else { return }
                onManipulatingChange(true)
            }
            .onEnded { value in
                onManipulatingChange(false)
                guard isSelected else { return }
                let width = max(canvasSize.width, 1)
                let proposedX = (basePosition.x + value.translation.width) / width
                let proposedY = basePosition.y + value.translation.height
                onUpdate(
                    instance.with(
                        normalizedX: min(max(proposedX, 0), 1),
                        y: max(proposedY, 0)
                    )
                )
            }

        let magnify = MagnifyGesture()
            .updating($bodyDelta) { value, state, _ in
                guard isSelected else { return }
                state.scaleFactor = value.magnification
            }
            .onChanged { _ in
                guard isSelected else { return }
                onManipulatingChange(true)
            }
            .onEnded { value in
                onManipulatingChange(false)
                guard isSelected else { return }
                onUpdate(instance.with(scale: instance.scale * value.magnification))
            }

        let rotate = RotateGesture(minimumAngleDelta: .degrees(1))
            .updating($bodyDelta) { value, state, _ in
                guard isSelected else { return }
                state.rotation = value.rotation
            }
            .onChanged { _ in
                guard isSelected else { return }
                onManipulatingChange(true)
            }
            .onEnded { value in
                onManipulatingChange(false)
                guard isSelected else { return }
                onUpdate(
                    instance.with(rotation: instance.rotation + CGFloat(value.rotation.radians))
                )
            }

        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
    }

    /// Single-finger drag on the top-trailing handle. Rotates and scales
    /// the sticker around its centre.
    private var rotateScaleGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: StickerOverlayView.canvasCoordinateSpace)
            .updating($handleDelta) { value, state, _ in
                let center = basePosition
                let initVector = CGVector(
                    dx: value.startLocation.x - center.x,
                    dy: value.startLocation.y - center.y
                )
                let liveVector = CGVector(
                    dx: value.location.x - center.x,
                    dy: value.location.y - center.y
                )
                let initAngle = atan2(initVector.dy, initVector.dx)
                let initDistance = max(hypot(initVector.dx, initVector.dy), 1)
                state.rotation = .radians(atan2(liveVector.dy, liveVector.dx) - initAngle)
                state.scaleFactor = hypot(liveVector.dx, liveVector.dy) / initDistance
            }
            .onChanged { _ in onManipulatingChange(true) }
            .onEnded { value in
                onManipulatingChange(false)
                let center = basePosition
                let initVector = CGVector(
                    dx: value.startLocation.x - center.x,
                    dy: value.startLocation.y - center.y
                )
                let liveVector = CGVector(
                    dx: value.location.x - center.x,
                    dy: value.location.y - center.y
                )
                let initAngle = atan2(initVector.dy, initVector.dx)
                let initDistance = max(hypot(initVector.dx, initVector.dy), 1)
                let angleDelta = atan2(liveVector.dy, liveVector.dx) - initAngle
                let scaleDelta = hypot(liveVector.dx, liveVector.dy) / initDistance
                onUpdate(
                    instance.with(
                        scale: instance.scale * scaleDelta,
                        rotation: instance.rotation + angleDelta
                    )
                )
            }
    }

    private func resetTransform() {
        onUpdate(instance.with(scale: 1.0, rotation: 0))
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let tail = instance.libraryRef.split(separator: ":").last.map(String.init) ?? instance.libraryRef
        let humanised = tail.replacingOccurrences(of: "-", with: " ")
        return String(localized: "Sticker: \(humanised)")
    }
}
