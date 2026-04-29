import Foundation

public struct UnimplementedInsightRepository: InsightRepository {
    public init() {}

    public func fetchAll() async throws -> [InsightSnapshot] {
        unimplemented(#function)
    }

    public func fetch(id: UUID) async throws -> InsightSnapshot? {
        unimplemented(#function)
    }

    public func save(_ insight: InsightSnapshot) async throws {
        unimplemented(#function)
    }

    public func delete(id: UUID) async throws {
        unimplemented(#function)
    }

    public func observeAll() -> AsyncStream<[InsightSnapshot]> {
        unimplemented(#function)
    }

    public func changes() -> AsyncStream<InsightChange> {
        unimplemented(#function)
    }

    private func unimplemented(_ method: String) -> Never {
        assertionFailure("UnimplementedInsightRepository.\(method) called — wire a real InsightRepository in ServiceContainer.")
        fatalError("UnimplementedInsightRepository.\(method)")
    }
}
