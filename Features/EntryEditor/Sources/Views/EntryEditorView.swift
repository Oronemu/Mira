import SwiftUI
import PhotosUI
import CoreKit
import DesignSystem

public struct EntryEditorView: View {
    @Environment(\.entryRepository) private var repository
    @Environment(\.photoStoring) private var photoStore
    @Environment(\.embeddingProvider) private var embeddingProvider
    @Environment(\.dismiss) private var dismiss

    @State private var state: EntryEditorState?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showMoodSheet = false
    @State private var showTagsSheet = false
    @State private var showPhotoPicker = false
    @State private var showDeleteConfirmation = false
    @State private var showTextStyleSheet = false
    @State private var showListStyleSheet = false
    @State private var showStickerSheet = false
    @State private var canvasSize: CGSize = .zero
    /// True while a sticker is being dragged / pinched / rotated. Drives
    /// the outer ScrollView's `.scrollDisabled(_:)` so the system pan
    /// recogniser can't compete with the sticker gesture mid-flight —
    /// that competition was the source of the drag jitter.
    @State private var isStickerManipulating: Bool = false
    @State private var viewer: PhotoViewerItem?
    @Namespace private var photoTransition
    @FocusState private var canvasFocused: Bool

    private let mode: EntryEditorState.Mode

    public init(mode: EntryEditorState.Mode) {
        self.mode = mode
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.75)
                .contentShape(Rectangle())
                .onTapGesture {
                    canvasFocused = false
                    state?.deselectSticker()
                }

            if let state {
                canvas(state: state)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: canvasFocused) { _, focused in
            if focused { state?.deselectSticker() }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) {
            if let state {
                bottomStack(state: state)
                    .offset(y: canvasFocused ? 0 : 15)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.9), value: canvasFocused)
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickerItems,
            maxSelectionCount: 3,
            matching: .images
        )
        .sheet(isPresented: $showMoodSheet) {
            if let state {
                MoodPickerSheet(selection: Binding(
                    get: { state.mood },
                    set: { state.mood = $0 }
                ))
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .sheet(isPresented: $showTagsSheet) {
            if let state {
                TagsSheet(
                    tags: state.tags,
                    onAdd: state.addTag,
                    onRemove: state.removeTag,
                    repository: repository
                )
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .sheet(isPresented: $showTextStyleSheet) {
            if let state {
                TextStyleSheet(
                    current: state.currentStyle,
                    onFontFamily: { state.applyFontFamily($0) },
                    onFontSize: { state.applyFontSize($0) },
                    onTextColor: { state.applyTextColor($0) },
                    onToggleBold: { state.toggleBold() },
                    onToggleItalic: { state.toggleItalic() },
                    onToggleUnderline: { state.toggleUnderline() }
                )
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .sheet(isPresented: $showListStyleSheet) {
            if let state {
                ListStyleSheet(
                    currentKind: state.currentLineToken?.kind ?? .paragraph,
                    canOutdent: (state.currentLineToken?.indent ?? 0) > 0,
                    apply: { state.applyListAction($0) }
                )
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .sheet(isPresented: $showStickerSheet) {
            if let state {
                StickerPickerSheet { libraryRef in
                    let dropPoint = CGPoint(
                        x: canvasSize.width / 2,
                        y: max(60, canvasSize.height / 3)
                    )
                    state.addSticker(
                        libraryRef: libraryRef,
                        at: dropPoint,
                        canvasSize: canvasSize
                    )
                    showStickerSheet = false
                }
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .fullScreenCover(item: $viewer) { item in
            FullscreenPhotoViewer(
                photos: item.photos,
                photoStore: photoStore,
                initialID: item.initialID,
                sourceID: item.initialID,
                namespace: photoTransition
            )
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    if let state, await state.delete() { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: pickerItems) { _, newItems in
            guard let state, !newItems.isEmpty else { return }
            Task { await ingest(items: newItems, into: state) }
        }
        .onChange(of: state?.content) { oldValue, newValue in
            guard let state,
                  let oldValue,
                  let newValue,
                  oldValue != newValue else { return }
            state.handleContentChange(oldValue: oldValue, newValue: newValue)
        }
        .task {
            if state == nil {
                state = EntryEditorState(
                    mode: mode,
                    repository: repository,
                    photoStore: photoStore,
                    embeddingProvider: embeddingProvider
                )
                if case .new = mode {
                    try? await Task.sleep(for: .milliseconds(220))
                    canvasFocused = true
                }
            }
        }
    }

    // MARK: - Title

    private var title: String {
        switch mode {
        case .new: String(localized: "New Entry")
        case .edit: String(localized: "Edit Entry")
        }
    }

    // MARK: - Canvas

    /// Page-style canvas: the whole thing is one scroll view, the
    /// TextEditor expands to its content (no internal scroll), and
    /// stickers live in the same scroll content layer — so they pin to
    /// the document and travel with the text when the user scrolls.
    /// This is the Apple-Notes / Notion model; the previous
    /// floating-overlay approach left stickers stuck to the viewport
    /// while text scrolled away beneath them.
    private func canvas(state: EntryEditorState) -> some View {
        GeometryReader { outer in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .eyebrowStyle()
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                        ZStack(alignment: .topLeading) {
                            if state.content.characters.isEmpty {
                                Text("Start writing…")
                                    .font(MiraTypography.entryBody)
                                    .foregroundStyle(MiraPalette.secondaryText.opacity(0.55))
                                    .padding(.top, 8)
                                    .padding(.leading, 20)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(
                                text: Binding(
                                    get: { state.content.resolvedForDisplay() },
                                    set: { state.content = $0 }
                                ),
                                selection: Binding(
                                    get: {
                                        state.selection
                                            ?? AttributedTextSelection(insertionPoint: state.content.startIndex)
                                    },
                                    set: { state.selection = $0 }
                                )
                            )
                            .lineSpacing(6)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .scrollDisabled(true)
                            .focused($canvasFocused)
                            .disabled(!state.isEditable)
                            .padding(.horizontal, 16)
                            .frame(minHeight: textEditorMinHeight(outer: outer))
                        }
                    }

                    StickerOverlayView(
                        stickers: state.stickers,
                        selectedID: Binding(
                            get: { state.selectedStickerID },
                            set: { newID in
                                state.selectedStickerID = newID
                                // Tapping a sticker dismisses the
                                // keyboard so the manipulation chrome
                                // isn't covered.
                                if newID != nil { canvasFocused = false }
                            }
                        ),
                        interactive: true,
                        onUpdate: { state.updateSticker($0) },
                        onRemove: { state.removeSticker(id: $0) },
                        onDuplicate: { state.duplicateSticker(id: $0) },
                        onBringForward: { state.bringStickerForward(id: $0) },
                        onSendBackward: { state.sendStickerBackward(id: $0) },
                        onManipulatingChange: { isStickerManipulating = $0 }
                    )
                    .allowsHitTesting(true)
                }
                .coordinateSpace(StickerOverlayView.canvasCoordinateSpace)
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { newSize in
                    canvasSize = newSize
                }
                .dropDestination(for: StickerDragPayload.self) { items, location in
                    guard let payload = items.first else { return false }
                    state.addSticker(
                        libraryRef: payload.libraryRef,
                        at: location,
                        canvasSize: canvasSize
                    )
                    showStickerSheet = false
                    return true
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, 140, for: .scrollContent)
            // Lock scroll while a sticker is being manipulated so the
            // ScrollView's pan recogniser doesn't compete with the
            // sticker's drag.
            .scrollDisabled(isStickerManipulating)
        }
    }

    /// Floor the TextEditor at roughly viewport height so a freshly-
    /// created entry feels like a full page, not a tiny field above
    /// blank space. Subtracts the eyebrow header's vertical room.
    private func textEditorMinHeight(outer proxy: GeometryProxy) -> CGFloat {
        max(240, proxy.size.height - 60)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if state?.canDelete == true {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.8))
                }
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { if let state, await state.save() { dismiss() } }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(saveTint)
                    .symbolEffect(
                        .variableColor,
                        options: .repeating,
                        isActive: state?.isSaving == true
                    )
            }
            .disabled(state?.canSave != true)
            .accessibilityLabel("Save")
        }
    }

    private var saveTint: Color {
        guard let state, state.canSave else {
            return MiraPalette.primaryText.opacity(0.85)
        }
        if let level = state.mood?.rawValue {
            return MiraPalette.mood(level: level)
        }
        return MiraPalette.accent
    }

    // MARK: - Bottom stack (photos + errors + dock)

    @ViewBuilder
    private func bottomStack(state: EntryEditorState) -> some View {
        VStack(spacing: 10) {
            if let error = state.errorMessage {
                ErrorPill(error)
                    .padding(.horizontal, 24)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            if !state.photos.isEmpty {
                PhotoStripView(
                    photos: state.photos,
                    photoStore: photoStore,
                    onRemove: { photo in Task { await state.removePhoto(photo) } },
                    onOpen: { photo in
                        viewer = PhotoViewerItem(
                            initialID: photo.id,
                            photos: state.photos
                        )
                    },
                    transitionNamespace: photoTransition
                )
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            dock(state: state)
        }
        .animation(.spring(duration: 0.35, bounce: 0.22), value: state.photos.map(\.id))
        .animation(.spring(duration: 0.3, bounce: 0.2), value: state.errorMessage)
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: canvasFocused)
    }

    private func dock(state: EntryEditorState) -> some View {
        EntryEditingDock(
            isExpanded: canvasFocused,
            mood: EntryEditingDock.Slot(
                indicator: state.mood.map { MiraPalette.mood(level: $0.rawValue) },
                isActive: state.mood != nil,
                isDisabled: !state.isEditable,
                action: { showMoodSheet = true }
            ),
            tags: EntryEditingDock.Slot(
                badgeCount: state.tags.count,
                isActive: !state.tags.isEmpty,
                isDisabled: !state.isEditable,
                action: { showTagsSheet = true }
            ),
            photos: EntryEditingDock.Slot(
                badgeCount: state.photos.count,
                isActive: !state.photos.isEmpty,
                isDisabled: !state.isEditable || state.photos.count >= 3,
                action: { showPhotoPicker = true }
            ),
            fontStyle: EntryEditingDock.Slot(
                isDisabled: !state.isEditable,
                action: { showTextStyleSheet = true }
            ),
            list: EntryEditingDock.Slot(
                isActive: state.currentLineToken?.kind != .paragraph
                    && state.currentLineToken != nil,
                isDisabled: !state.isEditable,
                action: { showListStyleSheet = true }
            ),
            stickers: EntryEditingDock.Slot(
                badgeCount: state.stickers.count,
                isActive: !state.stickers.isEmpty,
                isDisabled: state.stickers.count >= EntryEditorState.stickerLimit,
                action: { showStickerSheet = true }
            )
        )
    }

    // MARK: - Photo ingest

    private func ingest(items: [PhotosPickerItem], into state: EntryEditorState) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await state.attachPhoto(data)
            }
        }
        pickerItems = []
    }

    // MARK: - Derived

    private var ambientMoodLevels: [Int] {
        if let level = state?.mood?.rawValue {
            return [level]
        }
        return [3]
    }
}

/// Wrapper passed through `.fullScreenCover(item:)` so each tap presents
/// the viewer with a fresh identity and the exact photo collection it
/// should page through.
private struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let initialID: PhotoAssetSnapshot.ID
    let photos: [PhotoAssetSnapshot]
}
