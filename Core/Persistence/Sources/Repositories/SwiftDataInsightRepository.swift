import Foundation
import SwiftData
import CoreKit

@ModelActor
public actor SwiftDataInsightRepository: InsightRepository {
    private var observers: [UUID: AsyncStream<[InsightSnapshot]>.Continuation] = [:]
    private var changeObservers: [UUID: AsyncStream<InsightChange>.Continuation] = [:]

    // MARK: - InsightRepository

    public func fetchAll() async throws -> [InsightSnapshot] {
        try performFetch()
    }

    public func fetch(id: UUID) async throws -> InsightSnapshot? {
        let target = id
        let descriptor = FetchDescriptor<Insight>(predicate: #Predicate<Insight> { $0.id == target })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    public func save(_ insight: InsightSnapshot) async throws {
        let target = insight.id
        let descriptor = FetchDescriptor<Insight>(predicate: #Predicate<Insight> { $0.id == target })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.title = insight.title
            existing.content = insight.body
            existing.relatedEntryIDs = insight.referencedEntryIDs
            existing.type = insight.kind.persistenceType
        } else {
            let new = Insight(
                id: insight.id,
                createdAt: insight.createdAt,
                type: insight.kind.persistenceType,
                title: insight.title,
                content: insight.body,
                relatedEntryIDs: insight.referencedEntryIDs
            )
            modelContext.insert(new)
        }
        try modelContext.save()
        emitChange(.upserted(insight))
        notifyObservers()
    }

    public func delete(id: UUID) async throws {
        let target = id
        let descriptor = FetchDescriptor<Insight>(predicate: #Predicate<Insight> { $0.id == target })
        guard let insight = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(insight)
        try modelContext.save()
        emitChange(.deleted(id))
        notifyObservers()
    }

    public nonisolated func observeAll() -> AsyncStream<[InsightSnapshot]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.register(token: token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(token: token) }
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

    // MARK: - Private

    private func register(token: UUID, continuation: AsyncStream<[InsightSnapshot]>.Continuation) {
        observers[token] = continuation
        if let snapshot = try? performFetch() {
            continuation.yield(snapshot)
        }
    }

    private func unregister(token: UUID) {
        observers.removeValue(forKey: token)
    }

    private func notifyObservers() {
        guard let snapshot = try? performFetch() else { return }
        for continuation in observers.values {
            continuation.yield(snapshot)
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

    private func performFetch() throws -> [InsightSnapshot] {
        let descriptor = FetchDescriptor<Insight>(
            sortBy: [SortDescriptor(\Insight.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }
}

private extension InsightSnapshot.Kind {
    var persistenceType: InsightType {
        switch self {
        case .weeklyReflection: .weekly
        case .monthlyReflection: .monthly
        case .askMiraAnswer: .askMira
        }
    }
}
