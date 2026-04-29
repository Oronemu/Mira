import Foundation
import CoreKit

public actor MockEntryRepository: EntryRepository {
    public private(set) var entries: [UUID: EntrySnapshot] = [:]
    public private(set) var savedEntries: [EntrySnapshot] = []
    public private(set) var deletedIDs: [UUID] = []
    public private(set) var embeddings: [UUID: Data] = [:]

    private var observers: [UUID: ObserverHandle] = [:]
    private var changeObservers: [UUID: AsyncStream<EntryChange>.Continuation] = [:]

    public init(seed: [EntrySnapshot] = []) {
        for entry in seed { entries[entry.id] = entry }
    }

    public func fetchUnindexed(limit: Int) async throws -> [UnindexedEntry] {
        Array(entries.values
            .filter { embeddings[$0.id] == nil }
            .prefix(limit)
            .map { UnindexedEntry(id: $0.id, content: $0.plainContent) })
    }

    public func updateEmbedding(id: UUID, data: Data?) async throws {
        if let data { embeddings[id] = data }
        else { embeddings.removeValue(forKey: id) }
    }

    public func recentTags(limit: Int) async throws -> [String] {
        let ordered = entries.values.sorted { $0.updatedAt > $1.updatedAt }
        var seen = Set<String>()
        var result: [String] = []
        for entry in ordered {
            for tag in entry.tags where seen.insert(tag).inserted {
                result.append(tag)
                if result.count >= limit { return result }
            }
        }
        return result
    }

    public func fetchEmbedded() async throws -> [EmbeddedEntry] {
        entries.values.compactMap { (snapshot: EntrySnapshot) -> EmbeddedEntry? in
            guard let data = embeddings[snapshot.id], !data.isEmpty else { return nil }
            return EmbeddedEntry(
                id: snapshot.id,
                createdAt: snapshot.createdAt,
                content: snapshot.plainContent,
                embedding: []
            )
        }
    }

    public func fetch(matching query: EntryQuery) async throws -> [EntrySnapshot] {
        query.apply(to: Array(entries.values))
    }

    public func fetch(id: UUID) async throws -> EntrySnapshot? { entries[id] }

    public func save(_ entry: EntrySnapshot) async throws {
        entries[entry.id] = entry
        savedEntries.append(entry)
        emitChange(.upserted(entry))
        notifyObservers()
    }

    public func delete(id: UUID) async throws {
        entries.removeValue(forKey: id)
        deletedIDs.append(id)
        emitChange(.deleted(id))
        notifyObservers()
    }

    public nonisolated func observe(query: EntryQuery) -> AsyncStream<[EntrySnapshot]> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.register(token: token, query: query, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(token: token) }
            }
        }
    }

    public nonisolated func changes() -> AsyncStream<EntryChange> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.registerChanges(token: token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterChanges(token: token) }
            }
        }
    }

    // MARK: - Private

    private struct ObserverHandle {
        let query: EntryQuery
        let continuation: AsyncStream<[EntrySnapshot]>.Continuation
    }

    private func register(
        token: UUID,
        query: EntryQuery,
        continuation: AsyncStream<[EntrySnapshot]>.Continuation
    ) {
        observers[token] = ObserverHandle(query: query, continuation: continuation)
        continuation.yield(query.apply(to: Array(entries.values)))
    }

    private func unregister(token: UUID) {
        observers.removeValue(forKey: token)
    }

    private func notifyObservers() {
        for handle in observers.values {
            handle.continuation.yield(handle.query.apply(to: Array(entries.values)))
        }
    }

    private func registerChanges(token: UUID, continuation: AsyncStream<EntryChange>.Continuation) {
        changeObservers[token] = continuation
    }

    private func unregisterChanges(token: UUID) {
        changeObservers.removeValue(forKey: token)
    }

    private func emitChange(_ change: EntryChange) {
        for continuation in changeObservers.values {
            continuation.yield(change)
        }
    }
}
