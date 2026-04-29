import Foundation
import Observation
import SwiftUI
import CoreKit
import Utilities

@MainActor
@Observable
public final class EntryEditorState {
    public enum Mode: Sendable {
        case new
        case edit(EntrySnapshot)
    }

    public var content: AttributedString = AttributedString()
    public var mood: Mood?
    public var selection: AttributedTextSelection?
    public private(set) var tags: [String] = []
    public private(set) var photos: [PhotoAssetSnapshot] = []
    public private(set) var stickers: [EntryStickerInstance] = []
    public var selectedStickerID: UUID?
    public private(set) var isSaving: Bool = false
    public private(set) var errorMessage: String?

    /// Hard cap to keep the canvas readable and snapshots small.
    public static let stickerLimit = 12

    public let mode: Mode
    private let entryID: UUID
    private let createdAt: Date
    private let editWindow: TimeInterval = 24 * 60 * 60

    private let repository: any EntryRepository
    private let photoStore: any PhotoStoring
    private let embeddingProvider: any EmbeddingProvider
    private let clock: @Sendable () -> Date

    public init(
        mode: Mode,
        repository: any EntryRepository,
        photoStore: any PhotoStoring,
        embeddingProvider: any EmbeddingProvider,
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.mode = mode
        self.repository = repository
        self.photoStore = photoStore
        self.embeddingProvider = embeddingProvider
        self.clock = clock
        switch mode {
        case .new:
            self.entryID = UUID()
            self.createdAt = clock()
            self.content = AttributedString()
        case .edit(let existing):
            self.entryID = existing.id
            self.createdAt = existing.createdAt
            self.content = existing.content
            self.mood = existing.mood
            self.tags = existing.tags
            self.photos = existing.photos
            self.stickers = existing.stickers
        }
    }

    // MARK: - Derived state

    public var plainContent: String { String(content.characters) }

    /// 24h soft window — entries become read-only after that. Spec calls for
    /// a Settings toggle to disable; that lands with Settings in Week 8.
    public var isEditable: Bool {
        switch mode {
        case .new: true
        case .edit: clock().timeIntervalSince(createdAt) <= editWindow
        }
    }

    public var canSave: Bool {
        // Stickers ignore the 24h text-edit window — `isEditable` only
        // gates text mutations, not the save itself, so a sticker-only
        // change on an old entry can still be persisted.
        !trimmedContent.isEmpty && !isSaving
    }

    public var canDelete: Bool {
        if case .edit = mode { true } else { false }
    }

    private var trimmedContent: String {
        plainContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Selection helpers

    /// Character offset of the insertion point. Nil when selection isn't a
    /// single insertion (e.g. range selection) or not yet reported.
    public var cursorCharOffset: Int? {
        guard let selection else { return nil }
        switch selection.indices(in: content) {
        case .insertionPoint(let idx):
            return content.characters.distance(from: content.startIndex, to: idx)
        case .ranges(let ranges):
            guard let first = ranges.ranges.first else { return nil }
            return content.characters.distance(from: content.startIndex, to: first.lowerBound)
        }
    }

    /// Token describing the line the cursor sits on — used by the dock to
    /// light up the list button, compute indent/outdent availability, etc.
    public var currentLineToken: EntryLineToken? {
        guard let offset = cursorCharOffset else { return nil }
        return EntryContentEditor.lineInfo(in: content, at: offset)?.token
    }

    public func applyListAction(_ action: EntryContentEditor.ListAction) {
        guard isEditable, let offset = cursorCharOffset else { return }
        guard let result = EntryContentEditor.applyListAction(action, in: content, at: offset) else {
            return
        }
        content = result.content
        setCursor(charOffset: result.cursorCharOffset)
    }

    public func handleContentChange(oldValue: AttributedString, newValue: AttributedString) {
        guard isEditable else { return }

        // If the user applied a style with no selection, apply those attributes
        // to the characters they just typed so the style shows up on new text.
        var working = newValue
        let delta = newValue.characters.count - oldValue.characters.count
        if delta > 0, !pendingTyping.isEmpty, let offset = cursorCharOffset {
            let insertedEnd = offset
            let insertedStart = max(0, insertedEnd - delta)
            if insertedStart < insertedEnd {
                let chars = working.characters
                let startIdx = chars.index(chars.startIndex, offsetBy: insertedStart)
                let endIdx = chars.index(chars.startIndex, offsetBy: insertedEnd)
                pendingTyping.apply(to: &working, in: startIdx..<endIdx)
                pendingTyping = PendingTyping()
                if content != working { content = working }
            }
        }

        guard let offset = cursorCharOffset else { return }
        guard let result = EntryContentEditor.handleEnterContinuation(
            oldContent: oldValue,
            newContent: working,
            cursorCharOffset: offset
        ) else { return }
        content = result.content
        setCursor(charOffset: result.cursorCharOffset)
    }

    private func setCursor(charOffset: Int) {
        let chars = content.characters
        let clamped = max(0, min(charOffset, chars.count))
        let idx = chars.index(chars.startIndex, offsetBy: clamped)
        selection = AttributedTextSelection(insertionPoint: idx)
    }

    // MARK: - Text style mutations

    /// Current style under the selection. Fields are optional — nil means
    /// "mixed" for a range that spans runs with different values. Drives the
    /// Text Style sheet's preview and initial picker positions. When the user
    /// has toggled a style with no selection, the pending "typing" overrides
    /// are overlaid on top so the sheet reflects what will be applied to the
    /// next characters typed.
    public var currentStyle: EntrySelectionStyle {
        var style = EntrySelectionStyleReader.currentStyle(in: content, selection: selection)
        pendingTyping.overlay(&style)
        return style
    }

    public func applyFontFamily(_ family: EntryFontFamily) {
        guard isEditable else { return }
        if hasRangeSelection {
            applyToRange { $0[EntryFontFamilyAttribute.self] = family }
        } else {
            pendingTyping.family = family
        }
    }

    public func applyFontSize(_ size: EntryFontSize) {
        guard isEditable else { return }
        if hasRangeSelection {
            applyToRange { $0[EntryFontSizeAttribute.self] = size }
        } else {
            pendingTyping.size = size
        }
    }

    public func applyTextColor(_ color: EntryTextColor) {
        guard isEditable else { return }
        if hasRangeSelection {
            applyToRange { $0[EntryTextColorAttribute.self] = color }
        } else {
            pendingTyping.color = color
        }
    }

    public func toggleBold() {
        guard isEditable else { return }
        let on = currentStyle.bold == true
        if hasRangeSelection {
            applyToRange { $0[EntryBoldAttribute.self] = on ? nil : true }
        } else {
            pendingTyping.bold = !on
        }
    }

    public func toggleItalic() {
        guard isEditable else { return }
        let on = currentStyle.italic == true
        if hasRangeSelection {
            applyToRange { $0[EntryItalicAttribute.self] = on ? nil : true }
        } else {
            pendingTyping.italic = !on
        }
    }

    public func toggleUnderline() {
        guard isEditable else { return }
        let on = currentStyle.underline == true
        if hasRangeSelection {
            applyToRange { $0[EntryUnderlineAttribute.self] = on ? nil : true }
        } else {
            pendingTyping.underline = !on
        }
    }

    private var hasRangeSelection: Bool {
        guard let sel = selection else { return false }
        switch sel.indices(in: content) {
        case .insertionPoint: return false
        case .ranges(let ranges):
            return ranges.ranges.contains { $0.lowerBound < $0.upperBound }
        }
    }

    private func applyToRange(_ body: (inout AttributeContainer) -> Void) {
        guard var sel = selection else { return }
        content.transformAttributes(in: &sel) { container in
            body(&container)
        }
        selection = sel
    }

    // MARK: - Pending typing attributes

    private var pendingTyping = PendingTyping()

    // MARK: - Tags

    public func addTag(_ raw: String) {
        let normalised = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalised.isEmpty, !tags.contains(normalised) else { return }
        tags.append(normalised)
    }

    public func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    // MARK: - Photos

    public func attachPhoto(_ data: Data) async {
        do {
            let snapshot = try await photoStore.save(data)
            photos.append(snapshot)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func removePhoto(_ photo: PhotoAssetSnapshot) async {
        photos.removeAll { $0.id == photo.id }
        try? await photoStore.delete(relativePath: photo.relativePath)
    }

    // MARK: - Stickers

    /// Adds a sticker centred at the drop point. Normalises X relative to
    /// the canvas width so placement survives screen-width changes.
    public func addSticker(
        libraryRef: String,
        at point: CGPoint,
        canvasSize: CGSize
    ) {
        guard stickers.count < Self.stickerLimit else {
            errorMessage = String(localized: "Sticker limit reached.")
            return
        }
        let width = max(canvasSize.width, 1)
        let normalizedX = min(max(point.x / width, 0), 1)
        let nextZ = (stickers.map(\.zIndex).max() ?? 0) + 1
        let instance = EntryStickerInstance(
            libraryRef: libraryRef,
            normalizedX: normalizedX,
            y: max(0, point.y),
            zIndex: nextZ
        )
        stickers.append(instance)
        selectedStickerID = instance.id
    }

    public func updateSticker(_ updated: EntryStickerInstance) {
        guard let idx = stickers.firstIndex(where: { $0.id == updated.id }) else { return }
        stickers[idx] = updated
    }

    public func removeSticker(id: UUID) {
        stickers.removeAll { $0.id == id }
        if selectedStickerID == id { selectedStickerID = nil }
    }

    public func duplicateSticker(id: UUID) {
        guard stickers.count < Self.stickerLimit,
              let original = stickers.first(where: { $0.id == id }) else { return }
        let nextZ = (stickers.map(\.zIndex).max() ?? 0) + 1
        let copy = EntryStickerInstance(
            libraryRef: original.libraryRef,
            normalizedX: min(1, original.normalizedX + 0.05),
            y: original.y + 18,
            scale: original.scale,
            rotation: original.rotation,
            zIndex: nextZ
        )
        stickers.append(copy)
        selectedStickerID = copy.id
    }

    public func bringStickerForward(id: UUID) {
        guard let target = stickers.first(where: { $0.id == id }) else { return }
        let maxZ = stickers.map(\.zIndex).max() ?? 0
        guard target.zIndex < maxZ else { return }
        updateSticker(target.with(zIndex: maxZ + 1))
    }

    public func sendStickerBackward(id: UUID) {
        guard let target = stickers.first(where: { $0.id == id }) else { return }
        let minZ = stickers.map(\.zIndex).min() ?? 0
        guard target.zIndex > minZ else { return }
        updateSticker(target.with(zIndex: minZ - 1))
    }

    public func deselectSticker() {
        selectedStickerID = nil
    }

    // MARK: - Persistence

    @discardableResult
    public func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        let snapshot = EntrySnapshot(
            id: entryID,
            createdAt: createdAt,
            updatedAt: clock(),
            content: trimmedAttributedContent(),
            mood: mood,
            tags: tags,
            photos: photos,
            stickers: stickers
        )
        do {
            try await repository.save(snapshot)
            HapticsService().play(.success)
            let id = snapshot.id
            let plain = snapshot.plainContent
            let repository = repository
            let provider = embeddingProvider
            Task.detached {
                try? await repository.updateEmbedding(id: id, data: nil)
                try? await EmbeddingIndexingService().indexOne(
                    id: id,
                    content: plain,
                    using: provider,
                    repository: repository
                )
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            HapticsService().play(.error)
            return false
        }
    }

    /// Strips leading/trailing whitespace+newlines while preserving per-run
    /// attributes on the retained body.
    private func trimmedAttributedContent() -> AttributedString {
        let plain = plainContent
        let trimStart = plain.prefix(while: { $0.isWhitespace || $0.isNewline }).count
        let trimEnd = plain.reversed().prefix(while: { $0.isWhitespace || $0.isNewline }).count
        guard trimStart > 0 || trimEnd > 0 else { return content }
        var body = content
        let chars = body.characters
        let start = chars.index(chars.startIndex, offsetBy: trimStart)
        let endOffset = chars.count - trimEnd
        let end = chars.index(chars.startIndex, offsetBy: max(trimStart, endOffset))
        // Remove trailing first, then leading, so indices stay valid.
        if end < chars.endIndex {
            body.characters.removeSubrange(end..<body.endIndex)
        }
        if start > body.startIndex {
            body.characters.removeSubrange(body.startIndex..<start)
        }
        return body
    }

    @discardableResult
    public func delete() async -> Bool {
        errorMessage = nil
        do {
            try await repository.delete(id: entryID)
            for photo in photos {
                try? await photoStore.delete(relativePath: photo.relativePath)
            }
            HapticsService().play(.warning)
            return true
        } catch {
            errorMessage = error.localizedDescription
            HapticsService().play(.error)
            return false
        }
    }
}

/// Per-facet tri-state override applied to the next characters the user
/// types. `nil` means "no pending change"; a concrete value overrides whatever
/// would otherwise be inherited from the preceding run. Cleared in
/// `handleContentChange` once the new characters carry the attributes.
private struct PendingTyping {
    var family: EntryFontFamily?
    var size: EntryFontSize?
    var color: EntryTextColor?
    var bold: Bool?
    var italic: Bool?
    var underline: Bool?

    var isEmpty: Bool {
        family == nil && size == nil && color == nil
            && bold == nil && italic == nil && underline == nil
    }

    func overlay(_ style: inout EntrySelectionStyle) {
        if let v = family { style.family = v }
        if let v = size { style.size = v }
        if let v = color { style.color = v }
        if let v = bold { style.bold = v }
        if let v = italic { style.italic = v }
        if let v = underline { style.underline = v }
    }

    func apply(to content: inout AttributedString, in range: Range<AttributedString.Index>) {
        if let v = family { content[range][EntryFontFamilyAttribute.self] = v }
        if let v = size { content[range][EntryFontSizeAttribute.self] = v }
        if let v = color { content[range][EntryTextColorAttribute.self] = v }
        if let v = bold { content[range][EntryBoldAttribute.self] = v ? true : nil }
        if let v = italic { content[range][EntryItalicAttribute.self] = v ? true : nil }
        if let v = underline { content[range][EntryUnderlineAttribute.self] = v ? true : nil }
    }
}
