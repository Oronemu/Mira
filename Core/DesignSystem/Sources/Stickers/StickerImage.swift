import SwiftUI

/// Renders a sticker by its `libraryRef`. Falls back to a placeholder when
/// the ref isn't recognised (e.g. an entry from a future pack version on an
/// older binary). Renders the artwork in its original colours — the bundled
/// pack is full-colour PNG, not single-tone vector glyphs, so we keep the
/// designer's palette intact.
public struct StickerImage: View {
    /// Kept for source-compatibility with the previous template-tinting
    /// API; ignored now that the bundled artwork is full-colour PNG.
    public enum Tone {
        case inherit
        case ink
    }

    private let ref: String

    public init(libraryRef: String, tone: Tone = .ink) {
        self.ref = libraryRef
        _ = tone
    }

    public var body: some View {
        if let entry = StickerLibrary.entry(for: ref) {
            Image(entry.assetName, bundle: .module)
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Forward-compat: unknown ref renders as a soft placeholder
            // so a future pack reference doesn't crash an older build.
            Image(systemName: "questionmark.square.dashed")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(MiraPalette.primaryText.opacity(0.45))
        }
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
            ForEach(StickerLibrary.packs) { pack in
                Section {
                    ForEach(pack.entries) { entry in
                        StickerImage(libraryRef: entry.id)
                            .frame(width: 48, height: 48)
                    }
                } header: {
                    Text(pack.title).font(.caption)
                }
            }
        }
        .padding()
    }
    .background(MiraPalette.surface)
}
