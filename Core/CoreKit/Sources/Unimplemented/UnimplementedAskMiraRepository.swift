import Foundation

public struct UnimplementedAskMiraRepository: AskMiraRepository {
    public init() {}

    public func fetchChats() async throws -> [AskMiraChatSnapshot] { unimplemented(#function) }
    public func observeChats() -> AsyncStream<[AskMiraChatSnapshot]> { unimplemented(#function) }
    public func createChat(title: String) async throws -> UUID { unimplemented(#function) }
    public func renameChat(id: UUID, title: String) async throws { unimplemented(#function) }
    public func deleteChat(id: UUID) async throws { unimplemented(#function) }
    public func deleteAllChats() async throws { unimplemented(#function) }

    public func fetchTurns(chatID: UUID) async throws -> [AskMiraTurnSnapshot] { unimplemented(#function) }
    public func observeTurns(chatID: UUID) -> AsyncStream<[AskMiraTurnSnapshot]> { unimplemented(#function) }
    public func saveTurn(_ turn: AskMiraTurnSnapshot, chatID: UUID) async throws { unimplemented(#function) }

    private func unimplemented(_ method: String) -> Never {
        assertionFailure("UnimplementedAskMiraRepository.\(method) called — wire a real AskMiraRepository in ServiceContainer.")
        fatalError("UnimplementedAskMiraRepository.\(method)")
    }
}
