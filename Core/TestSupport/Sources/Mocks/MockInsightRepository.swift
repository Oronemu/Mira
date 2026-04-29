import Foundation
import CoreKit

public actor MockInsightRepository: InsightRepository {
    public private(set) var insights: [UUID: InsightSnapshot] = [:]

    private var changeObservers: [UUID: AsyncStream<InsightChange>.Continuation] = [:]

    public init(seed: [InsightSnapshot] = []) {
        for insight in seed { insights[insight.id] = insight }
    }

    public func fetchAll() async throws -> [InsightSnapshot] {
        Array(insights.values).sorted { $0.createdAt > $1.createdAt }
    }

    public func fetch(id: UUID) async throws -> InsightSnapshot? { insights[id] }

    public func save(_ insight: InsightSnapshot) async throws {
        insights[insight.id] = insight
        emitChange(.upserted(insight))
    }

    public func delete(id: UUID) async throws {
        insights.removeValue(forKey: id)
        emitChange(.deleted(id))
    }

    public nonisolated func observeAll() -> AsyncStream<[InsightSnapshot]> {
        AsyncStream { continuation in
            Task {
                if let snapshot = try? await self.fetchAll() {
                    continuation.yield(snapshot)
                }
                continuation.finish()
            }
        }
    }

    public nonisolated func changes() -> AsyncStream<InsightChange> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.registerChanges(token: token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterChanges(token: token) }
            }
        }
    }

    private func registerChanges(token: UUID, continuation: AsyncStream<InsightChange>.Continuation) {
        changeObservers[token] = continuation
    }

    private func unregisterChanges(token: UUID) {
        changeObservers.removeValue(forKey: token)
    }

    private func emitChange(_ change: InsightChange) {
        for continuation in changeObservers.values {
            continuation.yield(change)
        }
    }
}
