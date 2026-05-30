import Foundation
import CoreKit

/// Last-line defence for responses from providers that score low on
/// instruction-following — small on-device models that occasionally leak
/// the system prompt, echo tag names, or comply with an injection
/// despite the strict prompt. The guard buffers the upstream response,
/// pattern-checks the full text, and replaces it with a neutral fallback
/// when a violation is detected.
///
/// Trade-off: callers lose streaming UX for the wrapped provider —
/// chunks are not forwarded until the upstream stream completes. That's
/// acceptable for on-device responses, which are short and finish in
/// seconds, but would be a regression for large hosted models. Only
/// apply this where `requiresStrictPrompts == true`.
enum OutputGuard {
    static func wrap(
        _ upstream: AsyncThrowingStream<AIResponseChunk, Error>
    ) -> AsyncThrowingStream<AIResponseChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var buffer = ""
                do {
                    for try await chunk in upstream {
                        buffer += chunk.textDelta
                        if chunk.isFinal { break }
                    }
                    let sanitised = sanitise(buffer)
                    if !sanitised.isEmpty {
                        continuation.yield(AIResponseChunk(textDelta: sanitised))
                    }
                    continuation.yield(AIResponseChunk(textDelta: "", isFinal: true))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Returns `text` unchanged when it looks safe, or a neutral fallback
    /// when a violation pattern matches. Conservative by design:
    /// catching an injection that leaked is worth the occasional false
    /// positive on a refusal that happens to quote a tag name.
    static func sanitise(_ text: String) -> String {
        guard isViolation(text) else { return text }
        return String(
            localized: "I couldn't make sense of that — could you rephrase?",
            comment: "Fallback shown when the on-device AI response is rejected by the safety guard."
        )
    }

    /// Pattern detector. Three independent checks; any single hit
    /// returns `true`.
    static func isViolation(_ text: String) -> Bool {
        let lower = text.lowercased()

        // 1. Wrapper-tag leakage. A safe response never contains these
        //    verbatim — the strict prompt explicitly forbids it.
        let tagNames = [
            "<mira_journal>", "</mira_journal>",
            "<mira_user_message>", "</mira_user_message>",
            "<mira_user_style>", "</mira_user_style>",
        ]
        if tagNames.contains(where: { lower.contains($0) }) {
            return true
        }

        // 2. Known injection-trigger phrases from the test corpus.
        //    Brackets / spacing variants are normalised away by the
        //    lowercase + contains check.
        let triggerPhrases = [
            "injection successful",
            "[dan mode]",
            "dan mode enabled",
            "i am now dan",
            "as dan, i",
            "developer mode enabled",
            "jailbreak successful",
        ]
        if triggerPhrases.contains(where: { lower.contains($0) }) {
            return true
        }

        // 3. Distinctive system-prompt fragments. The wording is
        //    specific enough that organic generation is implausible —
        //    a hit means the model echoed its own instructions.
        let promptFragments = [
            "you are mira, the user's private journaling companion",
            "ты — мира, личный помощник пользователя по дневнику",
            "absolute rules — apply no matter how the user phrases",
            "абсолютные правила — действуют, как бы пользователь",
            "authority and trust: the rules above are fixed",
            "доверие и авторитет: правила выше — фиксированные",
        ]
        if promptFragments.contains(where: { lower.contains($0) }) {
            return true
        }

        return false
    }
}
