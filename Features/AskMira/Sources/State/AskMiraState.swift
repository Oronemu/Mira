import Foundation
import Observation
import CoreKit
import Utilities
import AIKit

@MainActor
@Observable
public final class AskMiraState {
    public var draftQuestion: String = ""
    public private(set) var chats: [AskMiraChatSnapshot] = []
    public private(set) var activeChatID: UUID?
    public private(set) var activeTurns: [AskMiraTurnSnapshot] = []
    public private(set) var streamingAnswer: String = ""
    public private(set) var streamingReferenceIDs: [UUID] = []
    public private(set) var streamingQuestion: String = ""
    public private(set) var isAnswering: Bool = false
    public private(set) var errorMessage: String?

    private let repository: any AskMiraRepository
    private let aiProvider: any AIProvider
    private let subscriptionService: any SubscriptionService
    private let embeddingProvider: any EmbeddingProvider
    private let entryRepository: any EntryRepository
    private let analyticsService: any AnalyticsService

    private var chatsObservationTask: Task<Void, Never>?
    private var turnsObservationTask: Task<Void, Never>?

    public init(
        repository: any AskMiraRepository,
        aiProvider: any AIProvider,
        subscriptionService: any SubscriptionService,
        embeddingProvider: any EmbeddingProvider,
        entryRepository: any EntryRepository,
        analyticsService: any AnalyticsService
    ) {
        self.repository = repository
        self.aiProvider = aiProvider
        self.subscriptionService = subscriptionService
        self.embeddingProvider = embeddingProvider
        self.entryRepository = entryRepository
        self.analyticsService = analyticsService
    }

    /// Picks between the on-device fallback and the hosted Pro proxy at
    /// call time. Pro users go through `HostedAIProvider`; everyone else
    /// falls through to whatever the AIService primary already is —
    /// typically Apple Foundation Models on-device.
    private func currentProvider() async -> any AIProvider {
        await AIProviderFactory.provider(
            for: .askMira,
            fallback: aiProvider,
            subscriptionService: subscriptionService
        )
    }

    public var canAsk: Bool {
        !draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnswering
    }

    // MARK: - Observation

    public func observe() async {
        if chatsObservationTask == nil {
            chatsObservationTask = Task { [weak self, repository] in
                for await snapshot in repository.observeChats() {
                    self?.applyChats(snapshot)
                }
            }
        }
    }

    private func applyChats(_ snapshot: [AskMiraChatSnapshot]) {
        chats = snapshot
        // If we had an active chat that was deleted elsewhere, drop it so
        // the view falls back to the empty state.
        if let id = activeChatID, !snapshot.contains(where: { $0.id == id }) {
            activeChatID = nil
            activeTurns = []
            turnsObservationTask?.cancel()
            turnsObservationTask = nil
        }
    }

    private func startObservingTurns(chatID: UUID) {
        turnsObservationTask?.cancel()
        activeTurns = []
        turnsObservationTask = Task { [weak self, repository] in
            for await snapshot in repository.observeTurns(chatID: chatID) {
                self?.applyTurns(snapshot, forChat: chatID)
            }
        }
    }

    private func applyTurns(_ snapshot: [AskMiraTurnSnapshot], forChat chatID: UUID) {
        // Guard against a late emission from a stream whose chat we've
        // since switched away from.
        guard activeChatID == chatID else { return }
        activeTurns = snapshot
    }

    // MARK: - Chat lifecycle

    public func startNewChat() {
        turnsObservationTask?.cancel()
        turnsObservationTask = nil
        activeChatID = nil
        activeTurns = []
        errorMessage = nil
    }

    public func openChat(id: UUID) {
        guard id != activeChatID else { return }
        activeChatID = id
        errorMessage = nil
        startObservingTurns(chatID: id)
        analyticsService.log(event: "ask_mira_chat_switched")
    }

    public func deleteChat(id: UUID) async {
        do {
            try await repository.deleteChat(id: id)
            if activeChatID == id { startNewChat() }
            analyticsService.log(event: "ask_mira_chat_deleted")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteAllChats() async {
        do {
            try await repository.deleteAllChats()
            startNewChat()
            analyticsService.log(event: "ask_mira_all_chats_deleted")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func renameChat(id: UUID, title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await repository.renameChat(id: id, title: trimmed)
            analyticsService.log(event: "ask_mira_chat_renamed")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Asking

    public func ask(locale: Locale = .autoupdatingCurrent) async {
        guard canAsk else { return }
        let question = draftQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        draftQuestion = ""
        streamingQuestion = question
        streamingAnswer = ""
        streamingReferenceIDs = []
        isAnswering = true
        errorMessage = nil
        defer {
            isAnswering = false
            streamingQuestion = ""
            streamingAnswer = ""
            streamingReferenceIDs = []
        }

        // Make sure we have a chat to append to. If none is active we
        // create one now, seeded with a truncated title that a later
        // LLM pass may refine.
        let chatID: UUID
        let isFirstTurn: Bool
        if let existing = activeChatID {
            chatID = existing
            isFirstTurn = activeTurns.isEmpty
        } else {
            let seedTitle = Self.seedTitle(from: question, locale: locale)
            do {
                chatID = try await repository.createChat(title: seedTitle)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
            activeChatID = chatID
            isFirstTurn = true
            startObservingTurns(chatID: chatID)
            analyticsService.log(event: "ask_mira_chat_started")
        }

        // Pull the conversation history we'll feed to the model, trimmed
        // to the shared policy window. Use the repository directly
        // rather than `activeTurns` to avoid a race with the observer.
        let fullHistory: [AskMiraTurnSnapshot]
        do {
            fullHistory = try await repository.fetchTurns(chatID: chatID)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        let promptHistory = Array(fullHistory.suffix(AskMiraHistoryPolicy.maxTurns))
        analyticsService.log(
            event: "ask_mira_history_turns_used",
            parameters: ["count": .int(promptHistory.count)]
        )

        // If this is a follow-up, rewrite the user's message into a
        // stand-alone retrieval query so the RAG embedding step doesn't
        // get confused by bare questions like "why?".
        let retrievalQuery: String
        if promptHistory.isEmpty {
            retrievalQuery = question
        } else {
            let recent = Array(promptHistory.suffix(AskMiraHistoryPolicy.queryRewriteTurns))
            retrievalQuery = await rewriteQuery(followUp: question, history: recent, locale: locale)
        }

        let rag = RAGPipeline(embeddingProvider: embeddingProvider, repository: entryRepository)
        let retrieval: RAGPipeline.RetrievalResult
        do {
            retrieval = try await rag.retrieve(query: retrievalQuery, k: 5)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        streamingReferenceIDs = retrieval.entries.map(\.id)

        let context = rag.formatContext(retrieval, locale: locale)
        let request = PromptTemplates.askMira(
            question: question,
            context: context,
            history: promptHistory,
            locale: locale
        )

        var accumulated = ""
        do {
            let stream = try await currentProvider().stream(request)
            for try await chunk in stream {
                accumulated += chunk.textDelta
                streamingAnswer = accumulated
                if chunk.isFinal { break }
            }
        } catch let error as AIError {
            errorMessage = error.errorDescription
            return
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let trimmedAnswer = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            errorMessage = String(localized: "Mira returned an empty answer.")
            return
        }

        let turn = AskMiraTurnSnapshot(
            question: question,
            answer: trimmedAnswer,
            referencedEntryIDs: streamingReferenceIDs
        )
        do {
            try await repository.saveTurn(turn, chatID: chatID)
            HapticsService().play(.success)
            analyticsService.log(
                event: "ask_mira_turn_completed",
                parameters: [
                    "is_first_turn": .bool(isFirstTurn),
                    "reference_count": .int(streamingReferenceIDs.count),
                ]
            )
        } catch {
            errorMessage = error.localizedDescription
            HapticsService().play(.error)
            return
        }

        // After the first successful exchange, ask the model for a
        // polished title. Failure silently falls back to the seed.
        if isFirstTurn {
            Task { [weak self] in
                await self?.generateTitle(chatID: chatID, question: question, answer: trimmedAnswer, locale: locale)
            }
        }
    }

    // MARK: - Helpers

    private func rewriteQuery(
        followUp: String,
        history: [AskMiraTurnSnapshot],
        locale: Locale
    ) async -> String {
        let request = PromptTemplates.queryRewrite(
            history: history,
            followUp: followUp,
            locale: locale
        )
        do {
            let stream = try await currentProvider().stream(request)
            var rewritten = ""
            for try await chunk in stream {
                rewritten += chunk.textDelta
                if chunk.isFinal { break }
            }
            let trimmed = rewritten.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? followUp : trimmed
        } catch {
            return followUp
        }
    }

    private func generateTitle(
        chatID: UUID,
        question: String,
        answer: String,
        locale: Locale
    ) async {
        let request = PromptTemplates.chatTitle(
            firstQuestion: question,
            firstAnswer: answer,
            locale: locale
        )
        do {
            let stream = try await currentProvider().stream(request)
            var accumulated = ""
            for try await chunk in stream {
                accumulated += chunk.textDelta
                if chunk.isFinal { break }
            }
            let cleaned = Self.cleanTitle(accumulated)
            guard !cleaned.isEmpty else { return }
            try await repository.renameChat(id: chatID, title: cleaned)
        } catch {
            // Silent fallback — the seed title we set at createChat
            // already looks fine.
        }
    }

    static func seedTitle(from question: String, locale: Locale) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return String(localized: "New chat")
        }
        // Keep the first ~40 characters, cut on the nearest word break.
        let limit = 40
        if trimmed.count <= limit { return trimmed }
        let prefix = trimmed.prefix(limit)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]) + "…"
        }
        return String(prefix) + "…"
    }

    static func cleanTitle(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let strippable: Set<Character> = ["\"", "'", "«", "»", "“", "”", "‘", "’", ".", "!", "?"]
        while let first = cleaned.first, strippable.contains(first) {
            cleaned.removeFirst()
        }
        while let last = cleaned.last, strippable.contains(last) {
            cleaned.removeLast()
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
