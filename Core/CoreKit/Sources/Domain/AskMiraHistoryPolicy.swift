import Foundation

/// Single source of truth for how much chat history is handed to the AI
/// provider on each turn. Centralised so prompt templates, state, and
/// analytics all agree on the window size.
public enum AskMiraHistoryPolicy {
    /// Maximum number of past turns (question/answer pairs) included in
    /// the prompt context for a follow-up question. Older turns are
    /// dropped from the oldest end first.
    public static let maxTurns: Int = 10

    /// Maximum number of past turns used when asking the model to rewrite
    /// the user's follow-up into a stand-alone retrieval query. Kept
    /// smaller than `maxTurns` because only the latest context matters
    /// for disambiguation.
    public static let queryRewriteTurns: Int = 4
}
