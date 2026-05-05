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
    private let analyticsService: any AnalyticsService
    private let crashReporter: any CrashReporter
    private let clock: @Sendable () -> Date

    public init(
        mode: Mode,
        repository: any EntryRepository,
        photoStore: any PhotoStoring,
        embeddingProvider: any EmbeddingProvider,
        analyticsService: any AnalyticsService = UnimplementedAnalyticsService(),
        crashReporter: any CrashReporter = UnimplementedCrashReporter(),
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.mode = mode
        self.repository = repository
        self.photoStore = photoStore
        self.embeddingProvider = embeddingProvider
        self.analyticsService = analyticsService
        self.crashReporter = crashReporter
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
            analyticsService.log(event: "entry_photo_attached")
        } catch {
            errorMessage = error.localizedDescription
            crashReporter.recordError(error, reason: "entry_editor.attach_photo")
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
        analyticsService.log(event: "entry_sticker_added")
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
            switch mode {
            case .new:
                analyticsService.log(
                    event: "entry_created",
                    parameters: [
                        "has_mood": .bool(mood != nil),
                        "tag_count": .int(tags.count),
                        "photo_count": .int(photos.count),
                        "sticker_count": .int(stickers.count),
                    ]
                )
            case .edit:
                analyticsService.log(event: "entry_edited")
            }
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
            crashReporter.recordError(error, reason: "entry_editor.save")
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
            analyticsService.log(event: "entry_deleted", parameters: ["source": .string("editor")])
            return true
        } catch {
            errorMessage = error.localizedDescription
            HapticsService().play(.error)
            crashReporter.recordError(error, reason: "entry_editor.delete")
            return false
        }
    }
}
