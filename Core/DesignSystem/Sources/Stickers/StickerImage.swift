import SwiftUI
import CoreKit
import UIKit

/// Renders a sticker by its `libraryRef`. Three resolution paths,
/// dispatched off the ref's namespace prefix:
///
/// - `"user:<uuid>"`: a user-created sticker. Bytes come from the
///   environment `CustomStickerStoring` via `CustomStickerByteCache`,
///   so re-mounts don't hit disk twice. Renders as transparent PNG.
/// - `"mira:<name>"`: bundled artwork — looked up in `StickerLibrary`
///   and drawn from `Stickers.xcassets`.
/// - anything else: forward-compat placeholder so a future ref shape
///   doesn't crash an older build.
public struct StickerImage: View {
    /// Kept for source-compatibility with the previous template-tinting
    /// API; ignored now that the bundled artwork is full-colour PNG.
    public enum Tone {
        case inherit
        case ink
    }

    @Environment(\.customStickerStore) private var customStickerStore

    private let ref: String

    @State private var userBytes: Data?

    public init(libraryRef: String, tone: Tone = .ink) {
        self.ref = libraryRef
        _ = tone
    }

    public var body: some View {
        if let id = CustomStickerAsset.id(fromLibraryRef: ref) {
            userSticker(id: id)
        } else if let entry = StickerLibrary.entry(for: ref) {
            Image(entry.assetName, bundle: .module)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "questionmark.square.dashed")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(MiraPalette.primaryText.opacity(0.45))
        }
    }

    @ViewBuilder
    private func userSticker(id: UUID) -> some View {
        if let userBytes, let ui = UIImage(data: userBytes) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Placeholder during the first load. Same footprint as the
            // bundled images so layout doesn't jump when bytes arrive.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .task(id: id) {
                    let relativePath = "Stickers/\(id.uuidString).png"
                    userBytes = await CustomStickerByteCache.shared.data(
                        for: id,
                        relativePath: relativePath,
                        loader: customStickerStore
                    )
                }
        }
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
            ForEach(StickerLibrary.pickerEntries) { entry in
                StickerImage(libraryRef: entry.id)
                    .frame(width: 48, height: 48)
            }
        }
        .padding()
    }
    .background(MiraPalette.surface)
}
