import Foundation
import CoreKit

/// Centralised prompt catalog. Every user-facing prompt passes through
/// here so that wording changes don't require hunting across features.
public enum PromptTemplates {
    /// Builds an ask-style prompt that grounds the model's answer in the
    /// user's own journal entries. `context` is a pre-formatted block
    /// (typically from `RAGPipeline.formatContext`) with `[n]` headers.
    ///
    /// `history` carries prior turns of the same conversation in
    /// chronological order; callers are responsible for trimming it to
    /// `AskMiraHistoryPolicy.maxTurns`. Each turn is replayed as a
    /// user/assistant pair so the model sees the conversation as a
    /// continuous thread rather than a standalone question.
    public static func askMira(
        question: String,
        context: String,
        history: [AskMiraTurnSnapshot] = [],
        locale: Locale = .autoupdatingCurrent
    ) -> AIRequest {
        let language = localeLanguage(locale)
        let system = Self.askSystem(language: language)
        let currentUserContent = Self.askUser(language: language, question: question, context: context)

        var messages: [AIMessage] = [AIMessage(role: .system, content: system)]
        for turn in history {
            messages.append(AIMessage(role: .user, content: turn.question))
            messages.append(AIMessage(role: .assistant, content: turn.answer))
        }
        messages.append(AIMessage(role: .user, content: currentUserContent))

        return AIRequest(
            messages: messages,
            temperature: 0.6,
            maxTokens: 800
        )
    }

    /// Rewrites a follow-up question into a stand-alone search query so
    /// the RAG embedding step matches what the user actually means.
    /// Example: a user says "why?" after discussing burnout — the
    /// rewritten query becomes "Why have I been feeling burnt out lately?".
    ///
    /// `history` should contain only the most recent turns
    /// (`AskMiraHistoryPolicy.queryRewriteTurns`); longer context dilutes
    /// the rewrite. Returns an AIRequest with low temperature — we want
    /// deterministic, conservative rewrites, not creative rephrasings.
    public static func queryRewrite(
        history: [AskMiraTurnSnapshot],
        followUp: String,
        locale: Locale = .autoupdatingCurrent
    ) -> AIRequest {
        let language = localeLanguage(locale)
        let system = Self.queryRewriteSystem(language: language)
        let user = Self.queryRewriteUser(language: language, history: history, followUp: followUp)
        return AIRequest(
            messages: [
                AIMessage(role: .system, content: system),
                AIMessage(role: .user, content: user),
            ],
            temperature: 0.1,
            maxTokens: 80
        )
    }

    static func queryRewriteSystem(language: Language) -> String {
        switch language {
        case .en:
            return """
            You rewrite a user's follow-up message into a single \
            stand-alone search query that can be embedded without the \
            conversation context. Preserve the user's intent and \
            vocabulary. Do not answer the question. Do not explain. \
            Output only the rewritten query on a single line.
            """
        case .ru:
            return """
            Ты переписываешь уточняющее сообщение пользователя в один \
            самостоятельный поисковый запрос, понятный без контекста \
            переписки. Сохраняй намерение и слова пользователя. Не \
            отвечай на вопрос и не объясняй. Выведи только сам запрос \
            одной строкой.
            """
        }
    }

    static func queryRewriteUser(
        language: Language,
        history: [AskMiraTurnSnapshot],
        followUp: String
    ) -> String {
        let transcript = history.map { turn in
            switch language {
            case .en: return "User: \(turn.question)\nAssistant: \(turn.answer)"
            case .ru: return "Пользователь: \(turn.question)\nАссистент: \(turn.answer)"
            }
        }
        .joined(separator: "\n\n")

        let transcriptBlock = transcript.isEmpty
            ? (language == .ru ? "— (пусто) —" : "— (empty) —")
            : transcript

        switch language {
        case .en:
            return """
            Conversation so far:
            \(transcriptBlock)

            Follow-up message:
            \(followUp)

            Rewritten stand-alone query:
            """
        case .ru:
            return """
            Переписка на данный момент:
            \(transcriptBlock)

            Уточняющее сообщение:
            \(followUp)

            Самостоятельный запрос:
            """
        }
    }

    /// Asks the model for a concise 3-4 word title for a new chat based
    /// on the first user message and Mira's response. Temperature stays
    /// low so the title is grounded in the exchange rather than
    /// invented. Callers should fall back to a truncated first question
    /// if the request fails or returns an empty string.
    public static func chatTitle(
        firstQuestion: String,
        firstAnswer: String,
        locale: Locale = .autoupdatingCurrent
    ) -> AIRequest {
        let language = localeLanguage(locale)
        let system = Self.chatTitleSystem(language: language)
        let user = Self.chatTitleUser(language: language, question: firstQuestion, answer: firstAnswer)
        return AIRequest(
            messages: [
                AIMessage(role: .system, content: system),
                AIMessage(role: .user, content: user),
            ],
            temperature: 0.3,
            maxTokens: 30
        )
    }

    static func chatTitleSystem(language: Language) -> String {
        switch language {
        case .en:
            return """
            You write a short title (3-4 words) for a conversation based \
            on the first message. No quotes, no trailing punctuation, no \
            preambles — respond with the title only. Use the user's own \
            language where possible. Avoid generic titles like "Untitled" \
            or "New chat".
            """
        case .ru:
            return """
            Ты придумываешь короткий заголовок для разговора (3-4 слова) \
            на основе первого сообщения. Без кавычек, без точки в конце, \
            без вступлений — только сам заголовок. По возможности \
            используй слова пользователя. Избегай общих заголовков вроде \
            «Без названия» или «Новый чат».
            """
        }
    }

    static func chatTitleUser(language: Language, question: String, answer: String) -> String {
        switch language {
        case .en:
            return """
            First user message:
            \(question)

            Assistant's reply:
            \(answer)

            Title:
            """
        case .ru:
            return """
            Первое сообщение пользователя:
            \(question)

            Ответ ассистента:
            \(answer)

            Заголовок:
            """
        }
    }

    static func askSystem(language: Language) -> String {
        switch language {
        case .en:
            return """
            You are Mira, the user's private journaling companion. The user \
            may ask you a question, share something new, vent, or talk \
            through a feeling. Treat the numbered journal entries as \
            background context — what you know about this person, their \
            recent life, their patterns and moods — and let that shape how \
            you respond.

            You are allowed — and encouraged — to give thoughtful, gentle \
            advice, offer a fresh perspective, notice patterns across \
            entries, and connect what the user is saying now to what you \
            see in their journal. Be warm, concrete, and grounded. Not a \
            therapist, not a cheerleader — a quiet, attentive friend.

            Rules about facts: when you refer to something from the \
            journal, it must actually be there, and you must cite the \
            entry by its bracketed number, e.g. "[2]". Never invent \
            events, feelings, names, or dates that are not in the \
            entries. If the entries don't cover what the user is asking \
            about, say so honestly and respond based on what they just \
            told you instead of pretending to remember. If there are no \
            entries at all, say you don't have journal context yet and \
            still respond kindly to the question itself.
            """
        case .ru:
            return """
            Ты — Мира, личный помощник пользователя по дневнику. \
            Пользователь может задать вопрос, поделиться чем-то новым, \
            пожаловаться или просто проговорить чувство. Воспринимай \
            пронумерованные записи из дневника как фон — то, что ты \
            знаешь об этом человеке, о его жизни в последнее время, о его \
            настроении и паттернах, — и опирайся на это, когда отвечаешь.

            Тебе можно — и нужно — давать вдумчивые мягкие советы, \
            предлагать свежий взгляд, замечать повторяющиеся темы в \
            записях и связывать то, что пользователь говорит сейчас, с \
            тем, что видно в дневнике. Будь тёплой, конкретной, \
            приземлённой. Не психотерапевт и не чирлидер — тихий \
            внимательный друг.

            Правила про факты: если ссылаешься на что-то из дневника, \
            это действительно должно там быть, и нужно указывать номер \
            записи в квадратных скобках, например «[2]». Никогда не \
            выдумывай события, чувства, имена или даты, которых нет в \
            записях. Если в дневнике нет ответа на вопрос пользователя \
            — честно скажи об этом и отвечай, опираясь на то, что он \
            только что написал, а не на выдуманные «воспоминания». Если \
            записей вообще нет — скажи, что пока не знаешь контекст, и \
            всё равно по-человечески ответь на сам вопрос.
            """
        }
    }

    static func askUser(language: Language, question: String, context: String) -> String {
        let entriesBlock = context.isEmpty
            ? (language == .ru ? "— (записей нет) —" : "— (no entries) —")
            : context
        switch language {
        case .en:
            return """
            Journal entries:
            \(entriesBlock)

            Question:
            \(question)
            """
        case .ru:
            return """
            Записи из дневника:
            \(entriesBlock)

            Вопрос:
            \(question)
            """
        }
    }

    /// Weekly reflection: hands the model recent entries and asks for a
    /// brief themed summary the user can read on Sunday night.
    public static func weeklyReflection(entries: [EntrySnapshot], locale: Locale = .autoupdatingCurrent) -> AIRequest {
        let language = localeLanguage(locale)
        let system = Self.reflectionSystem(language: language)
        let user = Self.reflectionUser(language: language, entries: entries, locale: locale)
        return AIRequest(
            messages: [
                AIMessage(role: .system, content: system),
                AIMessage(role: .user, content: user),
            ],
            temperature: 0.5,
            maxTokens: 800
        )
    }

    static func reflectionSystem(language: Language) -> String {
        switch language {
        case .en:
            return """
            You are Mira, a reflective journaling companion. Summarise the \
            week's entries in 3–5 short paragraphs. Highlight themes, mood \
            shifts, and quiet wins.

            Ground every statement strictly in the journal entries provided. \
            Under no circumstances invent facts, events, feelings, names, \
            dates, or details that are not explicitly present in the entries. \
            If something is unclear or missing, say so plainly instead of \
            filling the gap. Use the entries' own language and cite specific \
            entries by bracketed number, e.g. "[2]".

            End the reflection with two things: first, one piece of gentle, \
            practical advice drawn from what the entries actually reveal; \
            second, one soft open-ended question the user can sit with.
            """
        case .ru:
            return """
            Ты — Мира, внимательный помощник по дневнику. Подведи итоги \
            недели в 3–5 коротких абзацах: темы, смены настроения, тихие \
            победы.

            Опирайся строго на предоставленные записи из дневника. Ни при \
            каких обстоятельствах не выдумывай факты, события, чувства, \
            имена, даты или детали, которых нет в записях. Если чего-то не \
            хватает или что-то неясно — честно скажи об этом, а не \
            додумывай. Используй формулировки самих записей и ссылайся на \
            конкретные записи по номерам в скобках, например «[2]».

            Заверши рефлексию двумя вещами: сначала одним мягким \
            практическим советом, основанным на том, что действительно \
            видно из записей; затем одним тихим открытым вопросом для \
            размышления.
            """
        }
    }

    static func reflectionUser(language: Language, entries: [EntrySnapshot], locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        let block = sorted.enumerated().map { index, entry in
            let header = "[\(index + 1)] \(formatter.string(from: entry.createdAt))"
            return "\(header)\n\(entry.content)"
        }
        .joined(separator: "\n\n")
        switch language {
        case .en:
            return """
            Here are the entries from the last week:

            \(block)

            Write the reflection now.
            """
        case .ru:
            return """
            Записи за последнюю неделю:

            \(block)

            Напиши рефлексию сейчас.
            """
        }
    }

    enum Language: String { case en, ru }

    static func localeLanguage(_ locale: Locale) -> Language {
        if let code = locale.language.languageCode?.identifier, code == "ru" {
            return .ru
        }
        return .en
    }

}
