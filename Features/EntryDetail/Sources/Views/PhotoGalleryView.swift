import SwiftUI
import CoreKit
import DesignSystem

public struct PhotoGalleryView: View {
    private let photos: [PhotoAssetSnapshot]
    private let photoStore: any PhotoStoring
    private let onOpen: ((PhotoAssetSnapshot) -> Void)?
    private let transitionNamespace: Namespace.ID?

    @State private var currentID: PhotoAssetSnapshot.ID?

    public init(
        photos: [PhotoAssetSnapshot],
        photoStore: any PhotoStoring,
        onOpen: ((PhotoAssetSnapshot) -> Void)? = nil,
        transitionNamespace: Namespace.ID? = nil
    ) {
        self.photos = photos
        self.photoStore = photoStore
        self.onOpen = onOpen
        self.transitionNamespace = transitionNamespace
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return TabView(selection: $currentID) {
            ForEach(photos) { photo in
                GalleryPage(photo: photo, photoStore: photoStore)
                    .tag(Optional(photo.id))
                    .contentShape(Rectangle())
                    .matchedPhotoSource(id: photo.id, in: transitionNamespace)
                    .onTapGesture { onOpen?(photo) }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(MiraPalette.primaryText.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}

private extension View {
    @ViewBuilder
    func matchedPhotoSource(id: PhotoAssetSnapshot.ID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

private struct GalleryPage: View {
    let photo: PhotoAssetSnapshot
    let photoStore: any PhotoStoring

    @State private var image: Image?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            MiraPalette.secondaryBackground
            if let image {
                // `.scaledToFit` (not fill) so the gallery's rendering matches
                // what the full-screen viewer shows — otherwise the zoom-back
                // transition snaps at the end when the clipped crop in the
                // source differs from the fit-to-frame render in the viewer.
                image
                    .resizable()
                    .scaledToFit()
            } else if loadFailed {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(MiraPalette.secondaryText)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: photo.id) {
            await load()
        }
    }

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
