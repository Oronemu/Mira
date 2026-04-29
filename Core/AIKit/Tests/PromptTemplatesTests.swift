import Foundation
import Testing
@testable import AIKit
import CoreKit

@Suite("PromptTemplates")
struct PromptTemplatesTests {
    // MARK: - askMira

    @Test("askMira without history produces system + single user message")
    func askMiraNoHistory() {
        let request = PromptTemplates.askMira(
            question: "What's been on my mind?",
            context: "[1] 2026-04-20\nTired today.",
            history: [],
            locale: Locale(identifier: "en_US")
        )

        #expect(request.messages.count == 2)
        #expect(request.messages[0].role == .system)
        #expect(request.messages[1].role == .user)
        #expect(request.messages[1].content.contains("What's been on my mind?"))
    }

    @Test("askMira with history interleaves user and assistant messages")
    func askMiraWithHistory() {
        let t1 = AskMiraTurnSnapshot(question: "Q1", answer: "A1")
        let t2 = AskMiraTurnSnapshot(question: "Q2", answer: "A2")
        let request = PromptTemplates.askMira(
            question: "Q3",
            context: "",
            history: [t1, t2],
            locale: Locale(identifier: "en_US")
        )

        // system + 2×(user,assistant) + current user
        #expect(request.messages.count == 6)
        #expect(request.messages[0].role == .system)
        #expect(request.messages[1].role == .user)
        #expect(request.messages[1].content == "Q1")
        #expect(request.messages[2].role == .assistant)
        #expect(request.messages[2].content == "A1")
        #expect(request.messages[3].role == .user)
        #expect(request.messages[3].content == "Q2")
        #expect(request.messages[4].role == .assistant)
        #expect(request.messages[4].content == "A2")
        #expect(request.messages[5].role == .user)
        #expect(request.messages[5].content.contains("Q3"))
    }

    // MARK: - queryRewrite

    @Test("queryRewrite produces low-temperature request")
    func queryRewriteLowTemperature() {
        let request = PromptTemplates.queryRewrite(
            history: [],
            followUp: "why?",
            locale: Locale(identifier: "en_US")
        )
        #expect(request.temperature == 0.1)
        #expect(request.maxTokens == 80)
    }

    @Test("queryRewrite embeds history transcript and follow-up")
    func queryRewriteBuildsTranscript() {
        let t1 = AskMiraTurnSnapshot(question: "Why am I tired?", answer: "You wrote about late nights.")
        let request = PromptTemplates.queryRewrite(
            history: [t1],
            followUp: "and what should I do?",
            locale: Locale(identifier: "en_US")
        )

        let user = request.messages.last!.content
        #expect(user.contains("Why am I tired?"))
        #expect(user.contains("You wrote about late nights."))
        #expect(user.contains("and what should I do?"))
    }

    @Test("queryRewrite with empty history still works")
    func queryRewriteEmptyHistory() {
        let request = PromptTemplates.queryRewrite(
            history: [],
            followUp: "hello",
            locale: Locale(identifier: "en_US")
        )
        #expect(request.messages.count == 2)
        #expect(request.messages.last!.content.contains("hello"))
    }

    // MARK: - chatTitle

    @Test("chatTitle produces short, deterministic-leaning request")
    func chatTitleRequestShape() {
        let request = PromptTemplates.chatTitle(
            firstQuestion: "What's been weighing on me lately?",
            firstAnswer: "You've written about work stress and sleep.",
            locale: Locale(identifier: "en_US")
        )
        #expect(request.temperature == 0.3)
        #expect(request.maxTokens == 30)
        #expect(request.messages.count == 2)
        #expect(request.messages.last!.content.contains("What's been weighing on me lately?"))
    }

    @Test("chatTitle system prompt forbids generic titles")
    func chatTitleForbidsGeneric() {
        let request = PromptTemplates.chatTitle(
            firstQuestion: "q",
            firstAnswer: "a",
            locale: Locale(identifier: "en_US")
        )
        let system = request.messages.first!.content
        #expect(system.contains("Untitled") || system.contains("New chat"))
    }

    // MARK: - Locale routing

    @Test("Russian locale routes through Russian strings")
    func russianLocale() {
        let request = PromptTemplates.askMira(
            question: "Как дела?",
            context: "",
            history: [],
            locale: Locale(identifier: "ru_RU")
        )
        let system = request.messages.first!.content
        #expect(system.contains("Мира"))
    }
}
