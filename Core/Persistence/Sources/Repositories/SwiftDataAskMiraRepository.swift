import Foundation
import SwiftData
import CoreKit

/// SwiftData-backed chat store. Keeps chats and turns in sync, broadcasts
/// snapshots to observers, and — on first use after the schema gained
/// chat relations — groups any legacy orphan turns into per-day chats so
/// users upgrading from the flat-history build don't lose their journal
/// conversations.
@ModelActor
public actor SwiftDataAskMiraRepository: AskMiraRepository {
    private var chatObservers: [UUID: AsyncStream<[AskMiraChatSnapshot]>.Continuation] = [:]
    private var turnObservers: [UUID: (chatID: UUID, continuation: AsyncStream<[AskMiraTurnSnapshot]>.Continuation)] = [:]
    private var didMigrateLegacyTurns = false

    // MARK: - Chats

    public func fetchChats() async throws -> [AskMiraChatSnapshot] {
        try migrateLegacyTurnsIfNeeded()
        return try loadChats()
    }

    public nonisolated func observeChats() -> AsyncStream<[AskMiraChatSnapshot]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.registerChatObserver(token: token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterChatObserver(token: token) }
            }
        }
    }

    public func createChat(title: String) async throws -> UUID {
        try migrateLegacyTurnsIfNeeded()
        let chat = AskMiraChat(title: title)
        modelContext.insert(chat)
        try modelContext.save()
        notifyChatObservers()
        return chat.id
    }

    public func renameChat(id: UUID, title: String) async throws {
        guard let chat = try fetchChatModel(id: id) else { return }
        chat.title = title
        chat.updatedAt = .now
        try modelContext.save()
        notifyChatObservers()
    }

    public func deleteChat(id: UUID) async throws {
        guard let chat = try fetchChatModel(id: id) else { return }
        modelContext.delete(chat)
        try modelContext.save()
        notifyChatObservers()
        notifyTurnObservers(chatID: id)
    }

    public func deleteAllChats() async throws {
        let chats = try modelContext.fetch(FetchDescriptor<AskMiraChat>())
        let ids = chats.map(\.id)
        for chat in chats { modelContext.delete(chat) }
        try modelContext.save()
        notifyChatObservers()
        for id in ids { notifyTurnObservers(chatID: id) }
    }

    // MARK: - Turns

    public func fetchTurns(chatID: UUID) async throws -> [AskMiraTurnSnapshot] {
        try migrateLegacyTurnsIfNeeded()
        return try loadTurns(chatID: chatID)
    }

    public nonisolated func observeTurns(chatID: UUID) -> AsyncStream<[AskMiraTurnSnapshot]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.registerTurnObserver(token: token, chatID: chatID, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterTurnObserver(token: token) }
            }
        }
    }

    public func saveTurn(_ turn: AskMiraTurnSnapshot, chatID: UUID) async throws {
        guard let chat = try fetchChatModel(id: chatID) else {
            throw StorageError.notFound
        }
        let target = turn.id
        let descriptor = FetchDescriptor<AskMiraTurn>(predicate: #Predicate<AskMiraTurn> { $0.id == target })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.question = turn.question
            existing.answer = turn.answer
            existing.referencedEntryIDs = turn.referencedEntryIDs
            existing.chat = chat
        } else {
            let new = AskMiraTurn(
                id: turn.id,
                createdAt: turn.createdAt,
                question: turn.question,
                answer: turn.answer,
                referencedEntryIDs: turn.referencedEntryIDs,
                chat: chat
            )
            modelContext.insert(new)
        }
        if chat.updatedAt < turn.createdAt {
            chat.updatedAt = turn.createdAt
        }
        try modelContext.save()
        notifyChatObservers()
        notifyTurnObservers(chatID: chatID)
    }

    // MARK: - Observer registration

    private func registerChatObserver(token: UUID, continuation: AsyncStream<[AskMiraChatSnapshot]>.Continuation) {
        chatObservers[token] = continuation
        try? migrateLegacyTurnsIfNeeded()
        if let snapshot = try? loadChats() {
            continuation.yield(snapshot)
        }
    }

    private func unregisterChatObserver(token: UUID) {
        chatObservers.removeValue(forKey: token)
    }

    private func registerTurnObserver(
        token: UUID,
        chatID: UUID,
        continuation: AsyncStream<[AskMiraTurnSnapshot]>.Continuation
    ) {
        turnObservers[token] = (chatID, continuation)
        if let snapshot = try? loadTurns(chatID: chatID) {
            continuation.yield(snapshot)
        }
    }

    private func unregisterTurnObserver(token: UUID) {
        turnObservers.removeValue(forKey: token)
    }

    // MARK: - Observer fan-out

    private func notifyChatObservers() {
        guard let snapshot = try? loadChats() else { return }
        for (_, continuation) in chatObservers {
            continuation.yield(snapshot)
        }
    }

    private func notifyTurnObservers(chatID: UUID) {
        for (_, entry) in turnObservers where entry.chatID == chatID {
            if let snapshot = try? loadTurns(chatID: chatID) {
                entry.continuation.yield(snapshot)
            }
        }
    }

    // MARK: - Loading

    private func loadChats() throws -> [AskMiraChatSnapshot] {
        let descriptor = FetchDescriptor<AskMiraChat>(
            sortBy: [SortDescriptor(\AskMiraChat.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    private func loadTurns(chatID: UUID) throws -> [AskMiraTurnSnapshot] {
        let target = chatID
        let descriptor = FetchDescriptor<AskMiraTurn>(
            predicate: #Predicate<AskMiraTurn> { $0.chat?.id == target },
            sortBy: [SortDescriptor(\AskMiraTurn.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    private func fetchChatModel(id: UUID) throws -> AskMiraChat? {
        let target = id
        let descriptor = FetchDescriptor<AskMiraChat>(predicate: #Predicate<AskMiraChat> { $0.id == target })
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Legacy migration

    /// Collects all turns that have no owning chat (pre-schema-bump rows)
    /// and attaches them to a per-day `AskMiraChat` titled with the day's
    /// localised medium date. Runs at most once per actor lifetime.
    private func migrateLegacyTurnsIfNeeded() throws {
        guard !didMigrateLegacyTurns else { return }
        let descriptor = FetchDescriptor<AskMiraTurn>(
            predicate: #Predicate<AskMiraTurn> { $0.chat == nil }
        )
        let orphans = try modelContext.fetch(descriptor)
        guard !orphans.isEmpty else {
            didMigrateLegacyTurns = true
            return
        }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: orphans) { turn in
            calendar.startOfDay(for: turn.createdAt)
        }

        for (day, dayTurns) in grouped {
            let sorted = dayTurns.sorted { $0.createdAt < $1.createdAt }
            let chat = AskMiraChat(
                createdAt: sorted.first?.createdAt ?? day,
                updatedAt: sorted.last?.createdAt ?? day,
                title: formatter.string(from: day)
            )
            modelContext.insert(chat)
            for turn in sorted { turn.chat = chat }
        }

        try modelContext.save()
        didMigrateLegacyTurns = true
    }
}
