import SwiftUI
import PhotosUI
import CoreKit
import DesignSystem

public struct EntryDetailView: View {
    @Environment(\.entryRepository) private var repository
    @Environment(\.photoStoring) private var photoStore
    @Environment(\.embeddingProvider) private var embeddingProvider

    @State private var state: EntryDetailState?
    @State private var draft: EntryDraftState?
    @State private var isEditing = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showMoodSheet = false
    @State private var showTagsSheet = false
    @State private var showPhotoPicker = false
    @State private var showDeleteConfirmation = false
    @State private var showTextStyleSheet = false
    @State private var showListStyleSheet = false
    @State private var showStickerSheet = false
    @State private var canvasSize: CGSize = .zero
    @State private var isStickerManipulating: Bool = false
    @State private var didAutoDismiss = false
    @State private var viewer: PhotoViewerItem?
    @Namespace private var photoTransition
    @FocusState private var canvasFocused: Bool

    private let entryID: UUID
    private let onDismiss: () -> Void

    public init(entryID: UUID, onDismiss: @escaping () -> Void = {}) {
        self.entryID = entryID
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.7)
                .contentShape(Rectangle())
                .onTapGesture {
                    canvasFocused = false
                    draft?.deselectSticker()
                }

            Group {
                if let state {
                    content(state: state)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onChange(of: canvasFocused) { _, focused in
            if focused { draft?.deselectSticker() }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) {
            Group {
                if let draft {
                    bottomStack(draft: draft)
                }
            }
            .offset(y: isEditing ? (canvasFocused ? 0 : 15) : 200)
            .opacity(isEditing ? 1 : 0)
            .allowsHitTesting(isEditing)
            .animation(.spring(response: 0.48, dampingFraction: 0.88), value: isEditing)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: canvasFocused)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $pickerItems,
            maxSelectionCount: 3,
            matching: .images
        )
        .sheet(isPresented: $showMoodSheet) {
            if let draft {
                MoodPickerSheet(selection: Binding(
                    get: { draft.mood },
                    set: { draft.mood = $0 }
                ))
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .sheet(isPresented: $showTagsSheet) {
            if let draft {
                TagsSheet(
                    tags: draft.tags,
                    onAdd: draft.addTag,
                    onRemove: draft.removeTag,
                    repository: repository
                )
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .sheet(isPresented: $showTextStyleSheet) {
            if let draft {
                TextStyleSheet(
                    current: draft.currentStyle,
                    onFontFamily: { draft.applyFontFamily($0) },
                    onFontSize: { draft.applyFontSize($0) },
                    onTextColor: { draft.applyTextColor($0) },
                    onToggleBold: { draft.toggleBold() },
                    onToggleItalic: { draft.toggleItalic() },
                    onToggleUnderline: { draft.toggleUnderline() }
                )
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .sheet(isPresented: $showListStyleSheet) {
            if let draft {
                ListStyleSheet(
                    currentKind: draft.currentLineToken?.kind ?? .paragraph,
                    canOutdent: (draft.currentLineToken?.indent ?? 0) > 0,
                    apply: { draft.applyListAction($0) }
                )
                .presentationBackground {
                    AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)
                }
            }
        }
        .sheet(isPresented: $showStickerSheet) {
            if let draft {
                StickerPickerSheet { libraryRef in
                    let dropPoint = CGPoint(
                        x: canvasSize.width / 2,
                        y: max(60, canvasSize.height / 3)
                    )
                    draft.addSticker(
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
        .alert("Delete this entry?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteEntry() }
            }
        } message: {
            Text("This can't be undone.")
        }
        .onChange(of: pickerItems) { _, newItems in
            guard let draft, !newItems.isEmpty else { return }
            Task { await ingest(items: newItems, into: draft) }
        }
        .onChange(of: draft?.content) { oldValue, newValue in
            guard let draft,
                  let oldValue,
                  let newValue,
                  oldValue != newValue else { return }
            draft.handleContentChange(oldValue: oldValue, newValue: newValue)
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.88), value: isEditing)
        .task {
            if state == nil {
                state = EntryDetailState(entryID: entryID, repository: repository)
            }
            await state?.observe()
        }
    }

    // MARK: - Content switcher

    @ViewBuilder
    private func content(state: EntryDetailState) -> some View {
        if let snapshot = state.snapshot {
            if isEditing, let draft {
                editingCanvas(draft: draft)
                    .transition(.opacity)
            } else {
                readingCanvas(snapshot: snapshot)
                    .transition(.opacity)
            }
        } else if state.errorMessage != nil {
            // Entry was deleted (by us or sync). Bounce back to the list
            // once — avoid re-firing onDismiss if SwiftUI re-evaluates.
            Color.clear.task {
                guard !didAutoDismiss else { return }
                didAutoDismiss = true
                onDismiss()
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Reading canvas

    private func readingCanvas(snapshot: EntrySnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                readingHeader(snapshot)

                if snapshot.mood != nil {
                    MoodMedallion(mood: snapshot.mood)
                        .frame(maxWidth: .infinity)
                }

                if !snapshot.photos.isEmpty {
                    PhotoGalleryView(
                        photos: snapshot.photos,
                        photoStore: photoStore,
                        onOpen: { photo in
                            viewer = PhotoViewerItem(
                                initialID: photo.id,
                                photos: snapshot.photos
                            )
                        },
                        transitionNamespace: photoTransition
                    )
                    .frame(height: 330)
                }

                // Sticker `y` is stored as an offset from the top of the
                // editing canvas (which has a date eyebrow + spacing above
                // the text). Mirror that same eyebrow inset here as an
                // invisible placeholder so the overlay's coordinate
                // origin matches what the user placed in the editor —
                // otherwise stickers render lower than the text they
                // were anchored to.
                VStack(alignment: .leading, spacing: 12) {
                    Text(verbatim: " ")
                        .eyebrowStyle()
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .opacity(0)
                        .accessibilityHidden(true)

                    EntryContentRenderer(content: snapshot.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .overlay(alignment: .topLeading) {
                    StickerOverlayView(
                        stickers: snapshot.stickers,
                        selectedID: .constant(nil),
                        interactive: false,
                        onUpdate: { _ in },
                        onRemove: { _ in }
                    )
                }

                if !snapshot.tags.isEmpty {
                    tagRow(snapshot)
                }

                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func readingHeader(_ snapshot: EntrySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.createdAt, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .eyebrowStyle()
            Text(snapshot.createdAt, format: .dateTime.hour().minute())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MiraPalette.secondaryText)
            if snapshot.updatedAt > snapshot.createdAt.addingTimeInterval(1) {
                Text("Edited \(snapshot.updatedAt.formatted(.relative(presentation: .named)))")
                    .eyebrowStyle()
                    .padding(.top, 2)
            }
        }
        .padding(.top, 8)
    }

    private func tagRow(_ snapshot: EntrySnapshot) -> some View {
        let tintLevel = snapshot.mood?.rawValue
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(snapshot.tags, id: \.self) { tag in
                    TagPill(tag, tintLevel: tintLevel)
                }
            }
        }
    }

    // MARK: - Editing canvas

    /// Page-style editing canvas. Mirrors `EntryEditorView.canvas` —
    /// outer ScrollView, scroll-disabled TextEditor sized to content,
    /// stickers in the same scroll content layer so they pin to the
    /// document and travel with the text on scroll.
    private func editingCanvas(draft: EntryDraftState) -> some View {
        GeometryReader { outer in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .eyebrowStyle()
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                        ZStack(alignment: .topLeading) {
                            if draft.content.characters.isEmpty {
                                Text("Start writing…")
                                    .font(MiraTypography.entryBody)
                                    .foregroundStyle(MiraPalette.secondaryText.opacity(0.55))
                                    .padding(.top, 8)
                                    .padding(.leading, 20)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(
                                text: Binding(
                                    get: { draft.content.resolvedForDisplay() },
                                    set: { draft.content = $0 }
                                ),
                                selection: Binding(
                                    get: {
                                        draft.selection
                                            ?? AttributedTextSelection(insertionPoint: draft.content.startIndex)
                                    },
                                    set: { draft.selection = $0 }
                                )
                            )
                            .lineSpacing(6)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .scrollDisabled(true)
                            .focused($canvasFocused)
                            .padding(.horizontal, 16)
                            .frame(minHeight: max(240, outer.size.height - 60))
                        }
                    }

                    StickerOverlayView(
                        stickers: draft.stickers,
                        selectedID: Binding(
                            get: { draft.selectedStickerID },
                            set: { newID in
                                draft.selectedStickerID = newID
                                if newID != nil { canvasFocused = false }
                            }
                        ),
                        interactive: true,
                        onUpdate: { draft.updateSticker($0) },
                        onRemove: { draft.removeSticker(id: $0) },
                        onDuplicate: { draft.duplicateSticker(id: $0) },
                        onBringForward: { draft.bringStickerForward(id: $0) },
                        onSendBackward: { draft.sendStickerBackward(id: $0) },
                        onManipulatingChange: { isStickerManipulating = $0 }
                    )
                }
                .coordinateSpace(StickerOverlayView.canvasCoordinateSpace)
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { newSize in
                    canvasSize = newSize
                }
                .dropDestination(for: StickerDragPayload.self) { items, location in
                    guard let payload = items.first else { return false }
                    draft.addSticker(
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
            .scrollDisabled(isStickerManipulating)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isEditing {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                }
                .disabled(state?.snapshot == nil)
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)
        }

        ToolbarItem(placement: .primaryAction) {
            if isEditing {
                Button {
                    Task { await exitEditing() }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(checkmarkColor)
                        .symbolEffect(
                            .variableColor,
                            options: .repeating,
                            isActive: draft?.isSaving == true
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(!canCommitEdits)
                .accessibilityLabel(draft?.hasChanges == true ? "Save" : "Done")
            } else {
                Button {
                    if let snapshot = state?.snapshot {
                        enterEditing(snapshot: snapshot)
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(state?.snapshot == nil)
                .accessibilityLabel("Edit")
            }
        }
    }

    private var canCommitEdits: Bool {
        guard let draft else { return false }
        let trimmed = draft.plainContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !draft.isSaving
    }

    private var checkmarkColor: Color {
        guard let draft else { return MiraPalette.primaryText.opacity(0.85) }
        return draft.hasChanges ? moodTint(for: draft) : MiraPalette.primaryText.opacity(0.85)
    }

    // MARK: - Bottom stack (photos + errors + dock)

    @ViewBuilder
    private func bottomStack(draft: EntryDraftState) -> some View {
        VStack(spacing: 10) {
            if let error = draft.errorMessage {
                ErrorPill(error)
                    .padding(.horizontal, 24)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            if !draft.photos.isEmpty {
                PhotoStripView(
                    photos: draft.photos,
                    photoStore: photoStore,
                    onRemove: { photo in Task { await draft.removePhoto(photo) } },
                    onOpen: { photo in
                        viewer = PhotoViewerItem(
                            initialID: photo.id,
                            photos: draft.photos
                        )
                    },
                    transitionNamespace: photoTransition
                )
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            dock(draft: draft)
        }
        .animation(.spring(duration: 0.35, bounce: 0.22), value: draft.photos.map(\.id))
        .animation(.spring(duration: 0.3, bounce: 0.2), value: draft.errorMessage)
    }

    private func dock(draft: EntryDraftState) -> some View {
        EntryEditingDock(
            isExpanded: canvasFocused,
            mood: EntryEditingDock.Slot(
                indicator: draft.mood.map { MiraPalette.mood(level: $0.rawValue) },
                isActive: draft.mood != nil,
                action: { showMoodSheet = true }
            ),
            tags: EntryEditingDock.Slot(
                badgeCount: draft.tags.count,
                isActive: !draft.tags.isEmpty,
                action: { showTagsSheet = true }
            ),
            photos: EntryEditingDock.Slot(
                badgeCount: draft.photos.count,
                isActive: !draft.photos.isEmpty,
                isDisabled: draft.photos.count >= 3,
                action: { showPhotoPicker = true }
            ),
            fontStyle: EntryEditingDock.Slot(
                action: { showTextStyleSheet = true }
            ),
            list: EntryEditingDock.Slot(
                isActive: draft.currentLineToken?.kind != .paragraph
                    && draft.currentLineToken != nil,
                action: { showListStyleSheet = true }
            ),
            stickers: EntryEditingDock.Slot(
                badgeCount: draft.stickers.count,
                isActive: !draft.stickers.isEmpty,
                isDisabled: draft.stickers.count >= EntryDraftState.stickerLimit,
                action: { showStickerSheet = true }
            )
        )
    }

    // MARK: - Mode switching

    private func enterEditing(snapshot: EntrySnapshot) {
        draft = EntryDraftState(
            snapshot: snapshot,
            repository: repository,
            photoStore: photoStore,
            embeddingProvider: embeddingProvider
        )
        // Mount the overlay's Group at the hidden offset first, then flip
        // `isEditing` on the next tick so the spring animates from off-screen
        // up to its resting position instead of appearing in place.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            isEditing = true
        }
    }

    private func moodTint(for draft: EntryDraftState) -> Color {
        if let level = draft.mood?.rawValue {
            return MiraPalette.mood(level: level)
        }
        return MiraPalette.accent
    }

    private func exitEditing() async {
        guard let draft else { return }
        canvasFocused = false
        let trimmed = draft.plainContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if draft.hasChanges {
            guard await draft.save() else { return }
        }
        // Keep `draft` alive so the dock's offset animation plays out
        // smoothly — the next `enterEditing` will swap it for a fresh one.
        isEditing = false
    }

    private func deleteEntry() async {
        if let draft {
            _ = await draft.delete()
        } else if let snapshot = state?.snapshot {
            try? await repository.delete(id: snapshot.id)
            for photo in snapshot.photos {
                try? await photoStore.delete(relativePath: photo.relativePath)
            }
        }
        didAutoDismiss = true
        onDismiss()
    }

    // MARK: - Photo ingest

    private func ingest(items: [PhotosPickerItem], into draft: EntryDraftState) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await draft.attachPhoto(data)
            }
        }
        pickerItems = []
    }

    // MARK: - Derived

    private var ambientMoodLevels: [Int] {
        let level = draft?.mood?.rawValue ?? state?.snapshot?.mood?.rawValue
        return [level ?? 3]
    }
}

/// Wrapper passed through `.fullScreenCover(item:)` so the viewer gets a
/// fresh identity per tap and knows which collection to page through —
/// `snapshot.photos` when reading, `draft.photos` when editing.
private struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let initialID: PhotoAssetSnapshot.ID
    let photos: [PhotoAssetSnapshot]
}

// MARK: - Mood medallion

private struct MoodMedallion: View {
    let mood: Mood?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(auraColor.opacity(0.45))
                    .frame(width: 110, height: 110)
                    .blur(radius: 22)

                Circle()
                    .frame(width: 88, height: 88)
                    .glassEffect(.regular, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)

                if let mood {
                    Text(mood.emoji)
                        .font(.system(size: 42))
                        .accessibilityHidden(true)
                }
            }

            if let mood {
                Text(mood.label).eyebrowStyle()
            }
        }
    }

    private var auraColor: Color {
        mood.map { MiraPalette.mood(level: $0.rawValue) } ?? MiraPalette.moodUnknown
    }
}

// MARK: - Tag pill

private struct TagPill: View {
    let text: String
    let tintLevel: Int?

    init(_ text: String, tintLevel: Int?) {
        self.text = text
        self.tintLevel = tintLevel
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
            .background(Capsule().fill(background))
    }

    private var background: Color {
        if let tintLevel {
            return MiraPalette.mood(level: tintLevel).opacity(0.18)
        }
        return MiraPalette.secondaryBackground
    }
}
