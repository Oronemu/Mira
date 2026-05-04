import Foundation
import SwiftData
import WidgetKit
import CoreKit
import Utilities

@ModelActor
public actor SwiftDataEntryRepository: EntryRepository {
    private var observers: [UUID: ObserverHandle] = [:]
    private var changeObservers: [UUID: AsyncStream<EntryChange>.Continuation] = [:]

    // MARK: - EntryRepository

    public func fetch(matching query: EntryQuery) async throws -> [EntrySnapshot] {
        try performFetch(query)
    }

    public func fetch(id: UUID) async throws -> EntrySnapshot? {
        let target = id
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate<Entry> { $0.id == target })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    public func save(_ entry: EntrySnapshot) async throws {
        let target = entry.id
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate<Entry> { $0.id == target })
        let plain = entry.plainContent
        let contentData = try? EntryContentCodec.encode(entry.content)
        let stickersData: Data? = entry.stickers.isEmpty
            ? nil
            : (try? EntryStickersCodec.encode(entry.stickers))
        if let existing = try modelContext.fetch(descriptor).first {
            existing.content = plain
            existing.contentData = contentData
            existing.stickersData = stickersData
            existing.mood = entry.mood?.rawValue
            existing.tags = entry.tags
            existing.updatedAt = entry.updatedAt
            try reconcilePhotos(on: existing, with: entry.photos)
        } else {
            let new = Entry(
                id: entry.id,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt,
                content: plain,
                mood: entry.mood?.rawValue,
                tags: entry.tags,
                contentData: contentData,
                stickersData: stickersData
            )
            modelContext.insert(new)
            try reconcilePhotos(on: new, with: entry.photos)
        }
        try modelContext.save()
        emitChange(.upserted(entry))
        notifyObservers()
        reloadWidgets()
    }

    public func delete(id: UUID) async throws {
        let target = id
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate<Entry> { $0.id == target })
        guard let entry = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(entry)
        try modelContext.save()
        emitChange(.deleted(id))
        notifyObservers()
        reloadWidgets()
    }

    public func deleteAll() async throws {
        let descriptor = FetchDescriptor<Entry>()
        let all = try modelContext.fetch(descriptor)
        guard !all.isEmpty else { return }
        let ids = all.map(\.id)
        for entry in all {
            modelContext.delete(entry)
        }
        try modelContext.save()
        // Yield a `.deleted` event per row so CloudKitPusher tears
        // them down on other devices, mirroring single-row delete().
        for id in ids {
            emitChange(.deleted(id))
        }
        notifyObservers()
        reloadWidgets()
    }

    public func fetchUnindexed(limit: Int) async throws -> [UnindexedEntry] {
        var descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.embedding == nil },
            sortBy: [SortDescriptor(\Entry.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let entries = try modelContext.fetch(descriptor)
        return entries.map { UnindexedEntry(id: $0.id, content: $0.content) }
    }

    public func updateEmbedding(id: UUID, data: Data?) async throws {
        let target = id
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate<Entry> { $0.id == target })
        guard let entry = try modelContext.fetch(descriptor).first else { return }
        entry.embedding = data
        try modelContext.save()
    }

    public func fetchEmbedded() async throws -> [EmbeddedEntry] {
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.embedding != nil },
            sortBy: [SortDescriptor(\Entry.createdAt, order: .reverse)]
        )
        let entries = try modelContext.fetch(descriptor)
        return entries.compactMap { entry -> EmbeddedEntry? in
            guard let data = entry.embedding, !data.isEmpty,
                  let vector = EmbeddingCodec.decode(data) else {
                return nil
            }
            return EmbeddedEntry(
                id: entry.id,
                createdAt: entry.createdAt,
                content: entry.content,
                embedding: vector
            )
        }
    }

    public func recentTags(limit: Int) async throws -> [String] {
        var descriptor = FetchDescriptor<Entry>(
            sortBy: [SortDescriptor(\Entry.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        let entries = try modelContext.fetch(descriptor)
        var seen = Set<String>()
        var ordered: [String] = []
        for entry in entries {
            for tag in entry.tags where seen.insert(tag).inserted {
                ordered.append(tag)
                if ordered.count >= limit { return ordered }
            }
        }
        return ordered
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
        if let snapshot = try? performFetch(query) {
            continuation.yield(snapshot)
        }
    }

    private func unregister(token: UUID) {
        observers.removeValue(forKey: token)
    }

    private func notifyObservers() {
        for handle in observers.values {
            if let snapshot = try? performFetch(handle.query) {
                handle.continuation.yield(snapshot)
            }
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

    /// Nudges WidgetKit to re-run its timelines so the streak widget
    /// reflects new entries within seconds instead of waiting up to an
    /// hour for the next scheduled refresh. The call itself is cheap and
    /// the system coalesces frequent requests, so it's safe to fire on
    /// every write.
    private nonisolated func reloadWidgets() {
        Task { @MainActor in
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func performFetch(_ query: EntryQuery) throws -> [EntrySnapshot] {
        let descriptor = FetchDescriptor<Entry>(
            sortBy: [SortDescriptor(\Entry.createdAt, order: .reverse)]
        )
        let entries = try modelContext.fetch(descriptor)
        return query.apply(to: entries.map { $0.snapshot() })
    }

    private func reconcilePhotos(on entry: Entry, with photos: [PhotoAssetSnapshot]) throws {
        let desiredIDs = Set(photos.map(\.id))
        entry.photos.removeAll { !desiredIDs.contains($0.id) }
        let existingIDs = Set(entry.photos.map(\.id))
        for photo in photos where !existingIDs.contains(photo.id) {
            let asset = PhotoAsset(
                id: photo.id,
                relativePath: photo.relativePath,
                createdAt: photo.createdAt
            )
            asset.entry = entry
            entry.photos.append(asset)
            modelContext.insert(asset)
        }
    }
}
