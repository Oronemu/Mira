import SwiftUI
import CoreKit

/// Bottom sheet for picking a sticker. The primary interaction is
/// drag-out: each cell exposes a `StickerDragPayload` via `.draggable`,
/// and the host canvas registers a matching `.dropDestination` to place
/// the sticker at the drop point. A tap-to-add fallback is wired in too
/// (places at canvas centre) — covers VoiceOver and "I just want to add
/// it quickly" flows.
///
/// Layout: a Pro-gated "make a sticker" button sits above one flat
/// grid that mixes user-created stickers (newest first) and the bundled
/// drawstyle pack. No category headers — the bundled pack ships as a
/// single visual set after the drawstyle redesign.
public struct StickerPickerSheet: View {
    /// Called when the user taps a sticker as a fallback to drag-out.
    /// Caller is responsible for placement and dismissing the sheet.
    public typealias TapHandler = (_ libraryRef: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter
    @Environment(\.customStickerStore) private var customStickerStore

    private let onTap: TapHandler

    @State private var subscriptionStatus: SubscriptionStatus = .unknown
    @State private var userStickers: [CustomStickerAsset] = []
    @State private var showCreator = false

    public init(onTap: @escaping TapHandler) {
        self.onTap = onTap
    }

    public var body: some View {
        VStack(spacing: 0) {
            MiraSheetHeader(
                "Stickers",
                subtitle: "Drag onto the page — or tap to drop one in."
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    createButton
                    grid
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity)
        .miraSheet([.medium, .large])
        .task {
            subscriptionStatus = await subscriptionService.status
            await reloadUserStickers()
            for await snapshot in subscriptionService.statusUpdates {
                subscriptionStatus = snapshot
            }
        }
        .sheet(isPresented: $showCreator) {
            CustomStickerCreatorSheet { libraryRef in
                // Auto-place the freshly created sticker. Same UX as
                // tapping a bundled sticker: the host canvas places it
                // at its default drop point and dismisses the picker.
                onTap(libraryRef)
                Task { await reloadUserStickers() }
            }
            .presentationBackground {
                AmbientBackground(moodLevels: [3], intensity: 0.55)
            }
        }
    }

    // MARK: - Subviews

    private var createButton: some View {
        Button {
            tapCreateButton()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make your own")
                        .font(MiraTypography.body)
                        .foregroundStyle(MiraPalette.primaryText)
                    Text("Lift a subject from your photos.")
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                }
                Spacer()
                if !subscriptionStatus.isPro {
                    ProBadge()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MiraPalette.secondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(MiraPalette.secondaryBackground.opacity(0.6))
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Make your own sticker"))
        .accessibilityHint(subscriptionStatus.isPro
            ? Text("Opens the sticker creator.")
            : Text("Pro feature. Opens the upgrade screen."))
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
            spacing: 8
        ) {
            ForEach(userStickers) { asset in
                userCell(asset: asset)
            }
            ForEach(StickerLibrary.pickerEntries) { entry in
                cell(libraryRef: entry.id, isUser: false)
            }
        }
    }

    private func cell(libraryRef: String, isUser: Bool) -> some View {
        let payload = StickerDragPayload(libraryRef: libraryRef)
        return Button {
            onTap(libraryRef)
        } label: {
            StickerImage(libraryRef: libraryRef, tone: .ink)
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
            StickerImage(libraryRef: libraryRef, tone: .ink)
                .frame(width: 72, height: 72)
        }
        .accessibilityLabel(accessibilityLabel(for: libraryRef, isUser: isUser))
        .accessibilityHint("Double-tap to add. Drag with one finger to place.")
    }

    private func userCell(asset: CustomStickerAsset) -> some View {
        cell(libraryRef: asset.libraryRef, isUser: true)
            .contextMenu {
                Button(role: .destructive) {
                    Task { await delete(asset) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private func accessibilityLabel(for ref: String, isUser: Bool) -> String {
        if isUser {
            return String(localized: "Your sticker")
        }
        let tail = ref.split(separator: ":").last.map(String.init) ?? ref
        return tail.replacingOccurrences(of: "-", with: " ")
    }

    // MARK: - Actions

    private func tapCreateButton() {
        if subscriptionStatus.isPro {
            showCreator = true
        } else {
            paywallPresenter.present(.feature(.customStickers))
        }
    }

    private func reloadUserStickers() async {
        userStickers = (try? await customStickerStore.list()) ?? []
    }

    private func delete(_ asset: CustomStickerAsset) async {
        try? await customStickerStore.delete(id: asset.id)
        await CustomStickerByteCache.shared.invalidate(id: asset.id)
        await reloadUserStickers()
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
