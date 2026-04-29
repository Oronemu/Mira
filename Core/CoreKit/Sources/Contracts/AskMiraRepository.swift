import Foundation

/// Persistence boundary for AskMira. A store is a collection of chats;
/// each chat holds an ordered list of turns (oldest first).
///
/// Two reactive streams are exposed:
/// - `observeChats()` feeds the history sheet.
/// - `observeTurns(chatID:)` feeds the active conversation view.
public protocol AskMiraRepository: Sendable {

    // MARK: - Chats

    func fetchChats() async throws -> [AskMiraChatSnapshot]
    func observeChats() -> AsyncStream<[AskMiraChatSnapshot]>

    /// Creates a new empty chat and returns its id. The `title` is the
    /// initial best-effort title (typically a truncated first question);
    /// callers can refine it later via `renameChat`.
    func createChat(title: String) async throws -> UUID

    func renameChat(id: UUID, title: String) async throws
    func deleteChat(id: UUID) async throws
    func deleteAllChats() async throws

    // MARK: - Turns

    /// Returns turns in chronological order (oldest first). Suitable for
    /// feeding into an LLM as `[.user, .assistant, .user, ...]`.
    func fetchTurns(chatID: UUID) async throws -> [AskMiraTurnSnapshot]
    func observeTurns(chatID: UUID) -> AsyncStream<[AskMiraTurnSnapshot]>

    /// Appends a turn to the given chat and bumps the chat's
    /// `updatedAt`. The turn's own `createdAt` is preserved.
    func saveTurn(_ turn: AskMiraTurnSnapshot, chatID: UUID) async throws
}
