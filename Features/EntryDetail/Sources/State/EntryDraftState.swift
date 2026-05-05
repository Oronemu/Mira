import Foundation
import Observation
import SwiftUI
import CoreKit
import Utilities

/// In-place editing state for an existing entry shown in `EntryDetailView`.
/// Mirrors the relevant slice of `EntryEditorState` but is scoped to the
/// detail screen so the two feature modules stay independent.
@MainActor
@Observable
public final class EntryDraftState {
    public var content: AttributedString
    public var mood: Mood?
    public private(set) var tags: [String]
    public private(set) var photos: [PhotoAssetSnapshot]
    public private(set) var stickers: [EntryStickerInstance]
    public var selectedStickerID: UUID?
    public private(set) var isSaving: Bool = false
    public private(set) var errorMessage: String?

    /// Mirrors `EntryEditorState.stickerLimit` — kept independent so the two
    /// feature modules don't take a cross-feature dep on each other.
    public static let stickerLimit = 12

    private let entryID: UUID
    private let createdAt: Date

    private let originalPlainContent: String
    private let originalMood: Mood?
    private let originalTags: [String]
    private let originalPhotoIDs: Set<UUID>
    private let originalContentSignature: Data
    private let originalStickerSignature: Data

    private let repository: any EntryRepository
    private let photoStore: any PhotoStoring
    private let embeddingProvider: any EmbeddingProvider
    private let analyticsService: any AnalyticsService
    private let crashReporter: any CrashReporter
    private let clock: @Sendable () -> Date

    public init(
        snapshot: EntrySnapshot,
        repository: any EntryRepository,
        photoStore: any PhotoStoring,
        embeddingProvider: any EmbeddingProvider,
        analyticsService: any AnalyticsService = UnimplementedAnalyticsService(),
        crashReporter: any CrashReporter = UnimplementedCrashReporter(),
        clock: @escaping @Sendable () -> Date = { .now }
    ) {
        self.entryID = snapshot.id
        self.createdAt = snapshot.createdAt
        self.content = snapshot.content
        self.mood = snapshot.mood
        self.tags = snapshot.tags
        self.photos = snapshot.photos
        self.stickers = snapshot.stickers
        self.originalPlainContent = snapshot.plainContent
        self.originalMood = snapshot.mood
        self.originalTags = snapshot.tags
        self.originalPhotoIDs = Set(snapshot.photos.map(\.id))
        // Signature captures both plain text and attribute runs so we can
        // detect style-only edits without walking the AttributedString by
        // hand on every keystroke.
        self.originalContentSignature = (try? EntryContentCodec.encode(snapshot.content)) ?? Data()
        self.originalStickerSignature = (try? EntryStickersCodec.encode(snapshot.stickers)) ?? Data()
        self.repository = repository
        self.photoStore = photoStore
        self.embeddingProvider = embeddingProvider
        self.analyticsService = analyticsService
        self.crashReporter = crashReporter
        self.clock = clock
    }

    public var plainContent: String { String(content.characters) }

    /// True when the draft diverges from the snapshot it was spawned from —
    /// powers the save-button highlight and skips a no-op save/embedding pass.
    public var hasChanges: Bool {
        if mood != originalMood { return true }
        if tags != originalTags { return true }
        if Set(photos.map(\.id)) != originalPhotoIDs { return true }
        if plainContent != originalPlainContent { return true }
        // Attribute-only change — compare serialised form.
        let currentSignature = (try? EntryContentCodec.encode(content)) ?? Data()
        if currentSignature != originalContentSignature { return true }
        let currentStickerSignature = (try? EntryStickersCodec.encode(stickers)) ?? Data()
        return currentStickerSignature != originalStickerSignature
    }

    public var canSave: Bool {
        hasChanges && !trimmedContent.isEmpty && !isSaving
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
            crashReporter.recordError(error, reason: "entry_draft.attach_photo")
        }
    }

    public func removePhoto(_ photo: PhotoAssetSnapshot) async {
        photos.removeAll { $0.id == photo.id }
        if originalPhotoIDs.contains(photo.id) {
            // Defer disk delete until save commits — if the user backs out
            // without tapping save, the persisted entry still references
            // this file and would render a broken thumbnail next time.
            pendingPhotoDeletions.append(photo.relativePath)
        } else {
            try? await photoStore.delete(relativePath: photo.relativePath)
        }
    }

    private var pendingPhotoDeletions: [String] = []

    // MARK: - Stickers

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
            analyticsService.log(event: "entry_edited", parameters: ["source": .string("detail")])
            let pendingDeletions = pendingPhotoDeletions
            pendingPhotoDeletions = []
            for path in pendingDeletions {
                try? await photoStore.delete(relativePath: path)
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
            crashReporter.recordError(error, reason: "entry_draft.save")
            return false
        }
    }

    private func trimmedAttributedContent() -> AttributedString {
        let plain = plainContent
        let trimStart = plain.prefix(while: { $0.isWhitespace || $0.isNewline }).count
        let trimEnd = plain.reversed().prefix(while: { $0.isWhitespace || $0.isNewline }).count
        guard trimStart > 0 || trimEnd > 0 else { return content }
        var body = content
        let chars = body.characters
        let endOffset = chars.count - trimEnd
        let end = chars.index(chars.startIndex, offsetBy: max(trimStart, endOffset))
        if end < chars.endIndex {
            body.characters.removeSubrange(end..<body.endIndex)
        }
        let startIdx = body.characters.index(body.startIndex, offsetBy: trimStart)
        if startIdx > body.startIndex {
            body.characters.removeSubrange(body.startIndex..<startIdx)
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
            analyticsService.log(event: "entry_deleted", parameters: ["source": .string("detail")])
            return true
        } catch {
            errorMessage = error.localizedDescription
            HapticsService().play(.error)
            crashReporter.recordError(error, reason: "entry_draft.delete")
            return false
        }
    }
}
