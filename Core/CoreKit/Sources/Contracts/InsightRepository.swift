import Foundation

public protocol InsightRepository: Sendable {
    func fetchAll() async throws -> [InsightSnapshot]
    func fetch(id: UUID) async throws -> InsightSnapshot?
    func save(_ insight: InsightSnapshot) async throws
    func delete(id: UUID) async throws

    func observeAll() -> AsyncStream<[InsightSnapshot]>

    /// Per-row change stream consumed by the CloudKit pusher. Does not
    /// replay history — new subscribers only see events going forward.
    func changes() -> AsyncStream<InsightChange>
}
