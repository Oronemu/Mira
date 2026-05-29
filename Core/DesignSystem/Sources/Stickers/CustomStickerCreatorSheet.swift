import SwiftUI
import PhotosUI
import CoreKit
import Utilities
import UIKit

/// Flow for turning a photo into a transparent-background sticker.
/// `PhotosPicker` → on-device background removal → preview → save.
/// Nothing leaves the device — `StickerBackgroundRemover` runs Vision
/// locally, the resulting PNG is written through
/// `CustomStickerStoring`, and the libraryRef returned upstream so the
/// picker can highlight the newly created sticker on dismiss.
public struct CustomStickerCreatorSheet: View {
    public typealias SaveHandler = (_ libraryRef: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.customStickerStore) private var customStickerStore

    private let onSaved: SaveHandler

    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceBytes: Data?
    @State private var stickerBytes: Data?
    @State private var phase: Phase = .pickingPhoto
    @State private var errorMessage: String?

    public init(onSaved: @escaping SaveHandler) {
        self.onSaved = onSaved
    }

    private enum Phase: Equatable {
        case pickingPhoto
        case processing
        case ready
        case saving
    }

    public var body: some View {
        VStack(spacing: 0) {
            MiraSheetHeader(
                "Make a sticker",
                subtitle: "Pick a photo — we'll lift the subject and turn it into a sticker."
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    preview
                    actions
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.systemRed))
                    }
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity)
        .miraSheet([.medium, .large])
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await ingest(item) }
        }
    }

    // MARK: - Subviews

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(MiraPalette.secondaryBackground.opacity(0.6))
                .frame(height: 280)

            switch phase {
            case .pickingPhoto:
                emptyState
            case .processing:
                ProgressView()
                    .controlSize(.large)
            case .ready, .saving:
                if let stickerBytes, let ui = UIImage(data: stickerBytes) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(24)
                        .frame(maxHeight: 280)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 32))
                .foregroundStyle(MiraPalette.secondaryText)
            Text("Choose a photo to begin")
                .font(.system(size: 13))
                .foregroundStyle(MiraPalette.secondaryText)
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch phase {
        case .pickingPhoto, .processing:
            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text(phase == .processing ? "Processing…" : "Choose photo")
                    .font(MiraTypography.body)
                    .foregroundStyle(MiraPalette.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(MiraPalette.secondaryBackground)
                    )
            }
            .disabled(phase == .processing)
        case .ready, .saving:
            HStack(spacing: 12) {
                Button {
                    reset()
                } label: {
                    Text("Try another")
                        .font(MiraTypography.body)
                        .foregroundStyle(MiraPalette.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(MiraPalette.secondaryBackground.opacity(0.7))
                        )
                }
                .buttonStyle(.plain)
                .disabled(phase == .saving)

                Button {
                    Task { await save() }
                } label: {
                    Group {
                        if phase == .saving {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(MiraPalette.background)
                        } else {
                            Text("Save sticker")
                                .font(MiraTypography.body)
                                .foregroundStyle(MiraPalette.background)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(MiraPalette.primaryText)
                    )
                }
                .buttonStyle(.plain)
                .disabled(phase == .saving)
            }
        }
    }

    // MARK: - Flow

    private func reset() {
        pickerItem = nil
        sourceBytes = nil
        stickerBytes = nil
        errorMessage = nil
        phase = .pickingPhoto
    }

    private func ingest(_ item: PhotosPickerItem) async {
        errorMessage = nil
        phase = .processing
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = String(localized: "We couldn't load that photo.")
            phase = .pickingPhoto
            return
        }
        sourceBytes = data
        do {
            let remover = StickerBackgroundRemover()
            let png = try await remover.makeSticker(from: data)
            stickerBytes = png
            phase = .ready
        } catch {
            errorMessage = error.localizedDescription
            phase = .pickingPhoto
        }
    }

    private func save() async {
        guard let stickerBytes else { return }
        phase = .saving
        do {
            let asset = try await customStickerStore.save(stickerBytes)
            onSaved(asset.libraryRef)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            phase = .ready
        }
    }
}

#Preview("CustomStickerCreatorSheet") {
    struct Host: View {
        @State var shown = true
        var body: some View {
            Color.clear.sheet(isPresented: $shown) {
                CustomStickerCreatorSheet { _ in }
            }
        }
    }
    return Host()
}
