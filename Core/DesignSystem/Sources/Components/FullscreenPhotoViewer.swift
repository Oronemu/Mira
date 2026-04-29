import SwiftUI
import CoreKit

/// Full-screen photo viewer used by both the reading canvas (tapping the
/// gallery) and the editor's attachments strip (tapping a thumbnail).
/// Supports paging through all attached photos, pinch-to-zoom, pan-while-
/// zoomed, and double-tap to toggle zoom.
///
/// When presented via `.fullScreenCover` with a matching `namespace` +
/// `sourceID`, the view zooms in from the tapped thumbnail using the
/// iOS 18+ `.navigationTransition(.zoom(...))` API — which also brings
/// built-in interactive dismissal via swipe-down and pinch, so the
/// caller doesn't have to wire any gesture recognisers.
public struct FullscreenPhotoViewer: View {
    private let photos: [PhotoAssetSnapshot]
    private let photoStore: any PhotoStoring
    private let sourceID: PhotoAssetSnapshot.ID?
    private let namespace: Namespace.ID?

    @State private var currentID: PhotoAssetSnapshot.ID
    @Environment(\.dismiss) private var dismiss

    public init(
        photos: [PhotoAssetSnapshot],
        photoStore: any PhotoStoring,
        initialID: PhotoAssetSnapshot.ID,
        sourceID: PhotoAssetSnapshot.ID? = nil,
        namespace: Namespace.ID? = nil
    ) {
        self.photos = photos
        self.photoStore = photoStore
        self.sourceID = sourceID
        self.namespace = namespace
        self._currentID = State(initialValue: initialID)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentID) {
                ForEach(photos) { photo in
                    ZoomablePhoto(photo: photo, photoStore: photoStore)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            chrome
        }
        .statusBarHidden()
        // Match the system swipe-down dismiss with an upward counterpart so
        // either direction closes the viewer. Runs alongside TabView paging
        // (dominant-horizontal is filtered out) and ZoomablePhoto's own pan
        // (only active while zoomed, where translations stay short).
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let dx = abs(value.translation.width)
                    let dy = value.translation.height
                    if dy < -90, dx < 60 {
                        dismiss()
                    }
                }
        )
        .applyZoomTransition(sourceID: sourceID, namespace: namespace)
    }

    private var chrome: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            if photos.count > 1, let idx = currentIndex {
                Text("\(idx + 1) / \(photos.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.2), value: currentID)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var currentIndex: Int? {
        photos.firstIndex(where: { $0.id == currentID })
    }
}

private extension View {
    /// Applies the system zoom transition only when both a sourceID and a
    /// namespace are provided — otherwise the view is returned unchanged and
    /// falls back to the default `fullScreenCover` cross-fade.
    @ViewBuilder
    func applyZoomTransition(
        sourceID: PhotoAssetSnapshot.ID?,
        namespace: Namespace.ID?
    ) -> some View {
        if let sourceID, let namespace {
            self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}

// MARK: - Zoomable page
//
// Transform-based approach adapted from the MIT-licensed
// `ryohey/Zoomable` SwiftUI modifier. The single `CGAffineTransform`
// represents both scale and translation, which keeps the state coherent
// across pinch/pan/double-tap and makes it trivial to clamp on gesture
// end. Critically, the pan gesture is attached with
// `including: .none` whenever the transform is identity — so a horizontal
// drag on a non-zoomed photo falls through to the parent `TabView` page
// swipe instead of being swallowed.

private struct ZoomablePhoto: View {
    let photo: PhotoAssetSnapshot
    let photoStore: any PhotoStoring

    @State private var image: Image?
    @State private var loadFailed = false
    @State private var transform: CGAffineTransform = .identity
    @State private var lastTransform: CGAffineTransform = .identity
    @State private var contentSize: CGSize = .zero

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 5
    private let doubleTapZoom: CGFloat = 2.5

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(
                            x: transform.scaleX,
                            y: transform.scaleY,
                            anchor: .zero
                        )
                        .offset(x: transform.tx, y: transform.ty)
                        .gesture(
                            dragGesture,
                            including: transform.isIdentity ? .none : .all
                        )
                        .gesture(magnifyGesture)
                        .gesture(doubleTapGesture)
                } else if loadFailed {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    ProgressView().tint(.white)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear { contentSize = proxy.size }
            .onChange(of: proxy.size) { _, new in contentSize = new }
        }
        .task(id: photo.id) { await load() }
    }

    // MARK: Gestures

    private var magnifyGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0)
            .onChanged { value in
                let anchored = CGAffineTransform.anchoredScale(
                    scale: value.magnification,
                    anchor: value.startAnchor.scaledBy(contentSize)
                )
                withAnimation(.interactiveSpring) {
                    transform = lastTransform.concatenating(anchored)
                }
            }
            .onEnded { _ in finishGesture() }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let sx = max(transform.scaleX, .leastNonzeroMagnitude)
                let sy = max(transform.scaleY, .leastNonzeroMagnitude)
                withAnimation(.interactiveSpring) {
                    transform = lastTransform.translatedBy(
                        x: value.translation.width / sx,
                        y: value.translation.height / sy
                    )
                }
            }
            .onEnded { _ in finishGesture() }
    }

    private var doubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                let next: CGAffineTransform =
                    transform.isIdentity
                    ? .anchoredScale(scale: doubleTapZoom, anchor: value.location)
                    : .identity

                withAnimation(.linear(duration: 0.18)) {
                    transform = next
                    lastTransform = next
                }
                finishGesture()
            }
    }

    private func finishGesture() {
        let limited = clamp(transform)
        withAnimation(.snappy(duration: 0.1)) {
            transform = limited
            lastTransform = limited
        }
    }

    // MARK: Clamp

    private func clamp(_ t: CGAffineTransform) -> CGAffineTransform {
        if t.scaleX < minZoom || t.scaleY < minZoom { return .identity }

        var capped = t
        let current = max(t.scaleX, t.scaleY)
        if current > maxZoom {
            let factor = maxZoom / current
            let centre = CGPoint(x: contentSize.width / 2, y: contentSize.height / 2)
            let cap = CGAffineTransform.anchoredScale(scale: factor, anchor: centre)
            capped = capped.concatenating(cap)
        }

        // Keep the image pinned inside the viewport. Anchor-zero scaling means
        // the scaled image occupies `contentSize × scale`, so the maximum
        // translation before an edge goes past the viewport is
        // `contentSize × (scale - 1)`.
        let maxX = contentSize.width * (capped.scaleX - 1)
        let maxY = contentSize.height * (capped.scaleY - 1)
        if capped.tx > 0 || capped.tx < -maxX || capped.ty > 0 || capped.ty < -maxY {
            capped.tx = min(max(capped.tx, -maxX), 0)
            capped.ty = min(max(capped.ty, -maxY), 0)
        }

        return capped
    }

    // MARK: Load

    private func load() async {
        do {
            let data = try await photoStore.read(relativePath: photo.relativePath)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            } else {
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }
    }
}

// MARK: - Transform helpers

private extension CGAffineTransform {
    var scaleX: CGFloat { sqrt(a * a + c * c) }
    var scaleY: CGFloat { sqrt(b * b + d * d) }

    /// Scale around a given anchor point instead of the origin. Matches the
    /// pinch midpoint on a `MagnifyGesture.Value.startAnchor` location so the
    /// image zooms "into" where the user's fingers are.
    static func anchoredScale(scale: CGFloat, anchor: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: anchor.x, y: anchor.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -anchor.x, y: -anchor.y)
    }
}

private extension UnitPoint {
    func scaledBy(_ size: CGSize) -> CGPoint {
        .init(x: x * size.width, y: y * size.height)
    }
}
