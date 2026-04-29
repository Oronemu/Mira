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
@Suite("EntryEditorState — stickers")
struct EntryEditorStickerTests {
    private func makeState(
        mode: EntryEditorState.Mode = .new,
        clock: @escaping @Sendable () -> Date = { .now }
    ) -> EntryEditorState {
        EntryEditorState(
            mode: mode,
            repository: MockEntryRepository(),
            photoStore: MockPhotoStoring(),
            embeddingProvider: StubEmbeddingProvider(),
            clock: clock
        )
    }

    private let canvasSize = CGSize(width: 320, height: 600)

    @Test("addSticker normalises x and selects the new sticker")
    func addNormalises() {
        let state = makeState()
        let drop = CGPoint(x: 80, y: 120)
        state.addSticker(libraryRef: "phosphor:leaf", at: drop, canvasSize: canvasSize)

        #expect(state.stickers.count == 1)
        let placed = state.stickers[0]
        #expect(abs(placed.normalizedX - 0.25) < 1e-9)
        #expect(placed.y == 120)
        #expect(placed.zIndex == 1)
        #expect(state.selectedStickerID == placed.id)
    }

    @Test("addSticker stops at the limit and surfaces an error")
    func addRespectsLimit() {
        let state = makeState()
        for i in 0..<EntryEditorState.stickerLimit {
            state.addSticker(
                libraryRef: "phosphor:leaf",
                at: CGPoint(x: 10 * Double(i), y: 0),
                canvasSize: canvasSize
            )
        }
        #expect(state.stickers.count == EntryEditorState.stickerLimit)

        // One more — must be rejected.
        state.addSticker(
            libraryRef: "phosphor:heart",
            at: CGPoint(x: 0, y: 0),
            canvasSize: canvasSize
        )
        #expect(state.stickers.count == EntryEditorState.stickerLimit)
        #expect(state.errorMessage != nil)
    }

    @Test("updateSticker replaces by id")
    func updateById() {
        let state = makeState()
        state.addSticker(libraryRef: "phosphor:leaf", at: CGPoint(x: 100, y: 50), canvasSize: canvasSize)
        let original = state.stickers[0]

        state.updateSticker(original.with(scale: 1.8, rotation: 0.5))
        let updated = state.stickers[0]
        #expect(updated.id == original.id)
        #expect(updated.scale == 1.8)
        #expect(abs(updated.rotation - 0.5) < 1e-9)
    }

    @Test("removeSticker drops by id and clears selection if it matched")
    func removeClearsSelection() {
        let state = makeState()
        state.addSticker(libraryRef: "phosphor:leaf", at: .zero, canvasSize: canvasSize)
        let id = state.stickers[0].id
        #expect(state.selectedStickerID == id)

        state.removeSticker(id: id)
        #expect(state.stickers.isEmpty)
        #expect(state.selectedStickerID == nil)
    }

    @Test("duplicateSticker offsets and assigns a higher zIndex")
    func duplicateOrdering() {
        let state = makeState()
        state.addSticker(libraryRef: "phosphor:leaf", at: CGPoint(x: 100, y: 50), canvasSize: canvasSize)
        let original = state.stickers[0]

        state.duplicateSticker(id: original.id)
        #expect(state.stickers.count == 2)
        let copy = state.stickers[1]
        #expect(copy.id != original.id)
        #expect(copy.libraryRef == original.libraryRef)
        #expect(copy.zIndex > original.zIndex)
        #expect(copy.normalizedX > original.normalizedX)
        #expect(copy.y > original.y)
    }

    @Test("bring/send re-orders zIndex relative to peers")
    func reorderPeers() {
        let state = makeState()
        state.addSticker(libraryRef: "phosphor:leaf", at: .zero, canvasSize: canvasSize)
        state.addSticker(libraryRef: "phosphor:heart", at: .zero, canvasSize: canvasSize)
        state.addSticker(libraryRef: "phosphor:star", at: .zero, canvasSize: canvasSize)
        let leafID = state.stickers[0].id
        let heartID = state.stickers[1].id

        // leaf starts at the bottom — bring it forward, it overtakes star.
        state.bringStickerForward(id: leafID)
        let leafZ = state.stickers.first(where: { $0.id == leafID })!.zIndex
        let topZ = state.stickers.map(\.zIndex).max()!
        #expect(leafZ == topZ)

        // heart sent backward — its zIndex drops below the rest.
        state.sendStickerBackward(id: heartID)
        let heartZ = state.stickers.first(where: { $0.id == heartID })!.zIndex
        let bottomZ = state.stickers.map(\.zIndex).min()!
        #expect(heartZ == bottomZ)
    }

    @Test("save persists stickers through the snapshot")
    func savePersistsStickers() async throws {
        let repo = MockEntryRepository()
        let state = EntryEditorState(
            mode: .new,
            repository: repo,
            photoStore: MockPhotoStoring(),
            embeddingProvider: StubEmbeddingProvider()
        )
        state.content = "today"
        state.addSticker(libraryRef: "phosphor:leaf", at: CGPoint(x: 100, y: 80), canvasSize: canvasSize)

        let saved = await state.save()
        #expect(saved)

        let entries = try await repo.fetch(matching: .all)
        #expect(entries.count == 1)
        #expect(entries[0].stickers.count == 1)
        #expect(entries[0].stickers[0].libraryRef == "phosphor:leaf")
    }
}
