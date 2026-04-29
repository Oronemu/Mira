import Foundation
import SwiftData
import Testing
@testable import Persistence
import CoreKit

@MainActor
private func makeRepository() throws -> SwiftDataAskMiraRepository {
    let container = try ModelContainerFactory.inMemory()
    return SwiftDataAskMiraRepository(modelContainer: container)
}

@Suite("SwiftDataAskMiraRepository")
struct SwiftDataAskMiraRepositoryTests {
    @Test("createChat then fetchChats returns the chat")
    func createFetchChats() async throws {
        let repo = try await makeRepository()
        let id = try await repo.createChat(title: "First chat")
        let chats = try await repo.fetchChats()

        #expect(chats.count == 1)
        #expect(chats.first?.id == id)
        #expect(chats.first?.title == "First chat")
        #expect(chats.first?.turnCount == 0)
    }

    @Test("saveTurn appends to chat and bumps updatedAt")
    func saveTurnAppends() async throws {
        let repo = try await makeRepository()
        let id = try await repo.createChat(title: "Chat")
        let turnDate = Date(timeIntervalSinceNow: 60)
        let turn = AskMiraTurnSnapshot(
            createdAt: turnDate,
            question: "Hi",
            answer: "Hello"
        )

        try await repo.saveTurn(turn, chatID: id)
        let turns = try await repo.fetchTurns(chatID: id)
        let chats = try await repo.fetchChats()

        #expect(turns.count == 1)
        #expect(turns.first?.answer == "Hello")
        #expect(chats.first?.turnCount == 1)
        #expect(chats.first?.updatedAt == turnDate)
    }

    @Test("fetchTurns returns chronological order")
    func turnsChronological() async throws {
        let repo = try await makeRepository()
        let id = try await repo.createChat(title: "Chat")
        let early = AskMiraTurnSnapshot(createdAt: Date(timeIntervalSince1970: 100), question: "1", answer: "a")
        let later = AskMiraTurnSnapshot(createdAt: Date(timeIntervalSince1970: 200), question: "2", answer: "b")

        try await repo.saveTurn(later, chatID: id)
        try await repo.saveTurn(early, chatID: id)
        let turns = try await repo.fetchTurns(chatID: id)

        #expect(turns.map(\.question) == ["1", "2"])
    }

    @Test("deleteChat cascades its turns")
    func deleteCascades() async throws {
        let repo = try await makeRepository()
        let id = try await repo.createChat(title: "Chat")
        try await repo.saveTurn(
            AskMiraTurnSnapshot(question: "q", answer: "a"),
            chatID: id
        )

        try await repo.deleteChat(id: id)
        let chats = try await repo.fetchChats()
        let turns = try await repo.fetchTurns(chatID: id)

        #expect(chats.isEmpty)
        #expect(turns.isEmpty)
    }

    @Test("renameChat updates title")
    func renameChat() async throws {
        let repo = try await makeRepository()
        let id = try await repo.createChat(title: "old")

        try await repo.renameChat(id: id, title: "new")
        let chats = try await repo.fetchChats()

        #expect(chats.first?.title == "new")
    }

    @Test("legacy orphan turns are grouped by day on first fetch")
    func legacyMigrationGroupsByDay() async throws {
        let container = try await MainActor.run { try ModelContainerFactory.inMemory() }
        let context = await MainActor.run { ModelContext(container) }

        let day1 = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 9))!
        let day1b = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 14))!
        let day2 = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 11, hour: 10))!
        let orphanA = AskMiraTurn(createdAt: day1, question: "q1", answer: "a1")
        let orphanB = AskMiraTurn(createdAt: day1b, question: "q2", answer: "a2")
        let orphanC = AskMiraTurn(createdAt: day2, question: "q3", answer: "a3")
        await MainActor.run {
            context.insert(orphanA)
            context.insert(orphanB)
            context.insert(orphanC)
            try? context.save()
        }

        let repo = SwiftDataAskMiraRepository(modelContainer: container)
        let chats = try await repo.fetchChats()

        #expect(chats.count == 2)
        // Newer day sorts first by updatedAt desc.
        let firstChatID = chats[0].id
        let firstChatTurns = try await repo.fetchTurns(chatID: firstChatID)
        #expect(firstChatTurns.count == 1)
        let secondChatID = chats[1].id
        let secondChatTurns = try await repo.fetchTurns(chatID: secondChatID)
        #expect(secondChatTurns.count == 2)
    }
}
