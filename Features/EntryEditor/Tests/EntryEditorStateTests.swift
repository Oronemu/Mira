import Foundation
import Testing
@testable import FeatureEntryEditor
import CoreKit
import TestSupport

private struct StubEmbeddingProvider: EmbeddingProvider {
    var dimensions: Int { 0 }
    func embed(_ text: String) async throws -> [Float]? { nil }
}

@MainActor
@Suite("EntryEditorState")
struct EntryEditorStateTests {
    private func makeState(
        mode: EntryEditorState.Mode,
        seed: [EntrySnapshot] = [],
        clock: @escaping @Sendable () -> Date = { .now }
    ) -> (state: EntryEditorState, repo: MockEntryRepository, photos: MockPhotoStoring) {
        let repo = MockEntryRepository(seed: seed)
        let photos = MockPhotoStoring()
        let state = EntryEditorState(
            mode: mode,
            repository: repo,
            photoStore: photos,
            embeddingProvider: StubEmbeddingProvider(),
            clock: clock
        )
        return (state, repo, photos)
    }

    @Test("empty content blocks save")
    func emptyContentBlocksSave() async {
        let (state, _, _) = makeState(mode: .new)
        state.content = "   \n   "
        #expect(!state.canSave)
        let saved = await state.save()
        #expect(saved == false)
    }

    @Test("new mode persists trimmed content + mood + tags")
    func newSavePersists() async throws {
        let (state, repo, _) = makeState(mode: .new)
        state.content = "  Hello  "
        state.mood = .good
        state.addTag("Morning")
        state.addTag("morning") // duplicate, normalised → ignored

        let success = await state.save()
        #expect(success)

        let saved = await repo.savedEntries
        #expect(saved.count == 1)
        #expect(saved.first?.content == "Hello")
        #expect(saved.first?.mood == .good)
        #expect(saved.first?.tags == ["morning"])
    }

    @Test("edit mode within 24h is editable")
    func editableWithinWindow() {
        let createdAt = Date(timeIntervalSinceNow: -3600) // 1h ago
        let snapshot = EntrySnapshot(createdAt: createdAt, content: "old")
        let (state, _, _) = makeState(mode: .edit(snapshot))
        #expect(state.isEditable)
    }

    @Test("edit mode beyond 24h locks text mutations but still allows save")
    func textLockedAfterWindowButSaveable() {
        let createdAt = Date(timeIntervalSinceNow: -2 * 24 * 3600) // 2 days ago
        let snapshot = EntrySnapshot(createdAt: createdAt, content: "old")
        let (state, _, _) = makeState(mode: .edit(snapshot))
        // Text mutations remain gated by `isEditable` (the UI disables the
        // TextEditor too). The save itself isn't — sticker-only edits on
        // an old entry must still commit.
        #expect(!state.isEditable)
        #expect(state.canSave)
    }

    @Test("delete in edit mode removes entry and cleans up photos")
    func deleteRemovesEntry() async throws {
        let original = EntrySnapshot(content: "to delete")
        let (state, repo, photos) = makeState(mode: .edit(original), seed: [original])

        // Attach a photo first via the photo store so deletion has work to do.
        await state.attachPhoto(Data("png".utf8))
        let attachedPath = state.photos.first?.relativePath

        let deleted = await state.delete()
        #expect(deleted)

        let remaining = try await repo.fetch(matching: .all)
        #expect(remaining.isEmpty)
        if let attachedPath {
            await #expect(photos.deleted.contains(attachedPath))
        }
    }

    @Test("attachPhoto stores via photoStore and appends snapshot")
    func attachPhotoStores() async {
        let (state, _, photos) = makeState(mode: .new)
        await state.attachPhoto(Data("jpg".utf8))

        let stored = await photos.stored
        #expect(stored.count == 1)
        #expect(state.photos.count == 1)
    }

    @Test("removeTag removes by exact match")
    func removeTagWorks() {
        let (state, _, _) = makeState(mode: .new)
        state.addTag("focus")
        state.addTag("morning")
        state.removeTag("focus")
        #expect(state.tags == ["morning"])
    }
}
