import SwiftUI
import CoreKit

public struct PhotoStripView: View {
    private let photos: [PhotoAssetSnapshot]
    private let photoStore: any PhotoStoring
    private let onRemove: (PhotoAssetSnapshot) -> Void
    private let onOpen: ((PhotoAssetSnapshot) -> Void)?
    private let transitionNamespace: Namespace.ID?

    public init(
        photos: [PhotoAssetSnapshot],
        photoStore: any PhotoStoring,
        onRemove: @escaping (PhotoAssetSnapshot) -> Void,
        onOpen: ((PhotoAssetSnapshot) -> Void)? = nil,
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.photos = photos
        self.photoStore = photoStore
        self.onRemove = onRemove
        self.onOpen = onOpen
        self.transitionNamespace = transitionNamespace
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos) { photo in
                    PhotoThumb(
                        photo: photo,
                        photoStore: photoStore,
                        onRemove: onRemove,
                        onOpen: onOpen,
                        transitionNamespace: transitionNamespace
                    )
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .padding(.vertical, 4)
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: photos.map(\.id))
    }
}

private struct PhotoThumb: View {
    let photo: PhotoAssetSnapshot
    let photoStore: any PhotoStoring
    let onRemove: (PhotoAssetSnapshot) -> Void
    let onOpen: ((PhotoAssetSnapshot) -> Void)?
    let transitionNamespace: Namespace.ID?

    @State private var image: Image?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    image.resizable().scaledToFill()
                } else {
                    Rectangle()
                        .fill(MiraPalette.secondaryBackground)
                        .overlay(
                            ProgressView()
                                .controlSize(.mini)
                        )
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(MiraPalette.primaryText.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 7, x: 0, y: 3)
            .contentShape(shape)
            .matchedPhotoSource(id: photo.id, in: transitionNamespace)
            .onTapGesture {
                onOpen?(photo)
            }

            Button {
                onRemove(photo)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Remove photo")
        }
        .task(id: photo.id) { await loadImage() }
    }

    private func loadImage() async {
        do {
            let data = try await photoStore.read(relativePath: photo.relativePath)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            }
        } catch {
            // Surface via state container in a follow-up; thumbnail stays as spinner.
        }
    }
}

private extension View {
    /// Attaches `matchedTransitionSource` only when a namespace is actually
    /// provided by the host — so the component still works outside a zoom-
    /// transition context without requiring one.
    @ViewBuilder
    func matchedPhotoSource(id: PhotoAssetSnapshot.ID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
