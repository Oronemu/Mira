import Foundation
import CoreKit

/// Durable, append-only-ish queue of pending CloudKit pushes. Persisted
/// as JSON so changes made while the device is offline survive a
/// relaunch. Coalesces to latest-event-per-id: a rapid upsert→upsert
/// collapses to one record push, and a delete overwrites a queued
/// upsert because the latter would be wasted work.
public actor PendingPushQueue {
    public struct Item: Codable, Sendable, Hashable {
        public enum Operation: String, Codable, Sendable {
            case upsert
            case delete
        }

        public let id: UUID
        public let kind: SyncRecordKind
        public let operation: Operation
        public let updatedAt: Date

        public init(id: UUID, kind: SyncRecordKind, operation: Operation, updatedAt: Date) {
            self.id = id
            self.kind = kind
            self.operation = operation
            self.updatedAt = updatedAt
        }
    }

    private let url: URL
    private var items: [Item]

    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Item].self, from: data) {
            self.items = decoded
        } else {
            self.items = []
        }
    }

    public var count: Int { items.count }

    public var snapshot: [Item] { items }

    public func enqueue(_ item: Item) throws {
        items.removeAll { $0.id == item.id }
        items.append(item)
        try persist()
    }

    public func drain(limit: Int) -> [Item] {
        Array(items.prefix(limit))
    }

    public func markCompleted(_ ids: [UUID]) throws {
        let set = Set(ids)
        items.removeAll { set.contains($0.id) }
        try persist()
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: url, options: .atomic)
    }
}
