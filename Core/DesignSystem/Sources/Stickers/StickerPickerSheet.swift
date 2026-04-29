import SwiftUI

/// Bottom sheet for picking a sticker. The primary interaction is
/// drag-out: each cell exposes a `StickerDragPayload` via `.draggable`,
/// and the host canvas registers a matching `.dropDestination` to place
/// the sticker at the drop point. A tap-to-add fallback is wired in too
/// (places at canvas centre) — covers VoiceOver and "I just want to add
/// it quickly" flows.
public struct StickerPickerSheet: View {
    /// Called when the user taps a sticker as a fallback to drag-out.
    /// Caller is responsible for placement and dismissing the sheet.
    public typealias TapHandler = (_ libraryRef: String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let onTap: TapHandler

    public init(onTap: @escaping TapHandler) {
        self.onTap = onTap
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                ForEach(StickerLibrary.packs) { pack in
                    section(pack: pack)
                }
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationBackground(.clear)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(36)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stickers")
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
            Text("Drag onto the page — or tap to drop one in.")
                .font(.system(size: 13))
                .foregroundStyle(MiraPalette.secondaryText)
        }
        .padding(.top, 18)
    }

    private func section(pack: StickerLibrary.Pack) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(pack.title)
                .eyebrowStyle()

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                spacing: 8
            ) {
                ForEach(pack.entries) { entry in
                    cell(entry: entry)
                }
            }
        }
    }

    private func cell(entry: StickerLibrary.Entry) -> some View {
        let payload = StickerDragPayload(libraryRef: entry.id)
        return Button {
            onTap(entry.id)
        } label: {
            StickerImage(libraryRef: entry.id, tone: .ink)
                .frame(width: 44, height: 44)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MiraPalette.secondaryBackground.opacity(0.6))
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .draggable(payload) {
            // Drag preview — same image, slightly larger, no tile.
            StickerImage(libraryRef: entry.id, tone: .ink)
                .frame(width: 72, height: 72)
        }
        .accessibilityLabel(accessibilityLabel(for: entry.id))
        .accessibilityHint("Double-tap to add. Drag with one finger to place.")
    }

    private func accessibilityLabel(for ref: String) -> String {
        // Strip the "phosphor:" prefix and humanise the rest. Good enough
        // for VO without per-sticker localisation; we can enrich later.
        let tail = ref.split(separator: ":").last.map(String.init) ?? ref
        return tail.replacingOccurrences(of: "-", with: " ")
    }
}

#Preview("StickerPickerSheet") {
    struct Host: View {
        @State var shown = true
        var body: some View {
            Color.clear.sheet(isPresented: $shown) {
                StickerPickerSheet { _ in }
            }
        }
    }
    return Host()
}
