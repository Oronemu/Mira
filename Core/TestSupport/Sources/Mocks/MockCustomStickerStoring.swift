import Foundation
import CoreKit

public actor MockCustomStickerStoring: CustomStickerStoring {
    public private(set) var stored: [UUID: Data] = [:]
    public private(set) var createdAt: [UUID: Date] = [:]
    public private(set) var deleted: [UUID] = []
    private var observers: [UUID: AsyncStream<CustomStickerChange>.Continuation] = [:]

    public init() {}

    public func save(_ pngData: Data) async throws -> CustomStickerAsset {
        try await save(pngData, id: UUID(), createdAt: .now)
    }

    @discardableResult
    public func save(_ pngData: Data, id: UUID, createdAt: Date) async throws -> CustomStickerAsset {
        stored[id] = pngData
        self.createdAt[id] = createdAt
        let asset = CustomStickerAsset(
            id: id,
            relativePath: "Stickers/\(id.uuidString).png",
            createdAt: createdAt
        )
        emit(.upserted(asset))
        return asset
    }

    public func exists(id: UUID) async -> Bool {
        stored[id] != nil
    }

    public func read(relativePath: String) async throws -> Data {
        let name = (relativePath as NSString).lastPathComponent
        let stem = (name as NSString).deletingPathExtension
        guard let id = UUID(uuidString: stem), let data = stored[id] else {
            throw NSError(domain: "MockCustomStickerStoring", code: 404)
        }
        return data
    }

    public func delete(id: UUID) async throws {
        stored.removeValue(forKey: id)
        createdAt.removeValue(forKey: id)
        deleted.append(id)
        emit(.deleted(id))
    }

    public func list() async throws -> [CustomStickerAsset] {
        stored.keys.map { id in
            CustomStickerAsset(
                id: id,
                relativePath: "Stickers/\(id.uuidString).png",
                createdAt: createdAt[id] ?? .distantPast
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    public nonisolated func changes() -> AsyncStream<CustomStickerChange> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.register(token: token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(token: token) }
            }
        }
    }

    private func register(
        token: UUID,
        continuation: AsyncStream<CustomStickerChange>.Continuation
    ) {
        observers[token] = continuation
    }

    private func unregister(token: UUID) {
        observers.removeValue(forKey: token)
    }

    private func emit(_ change: CustomStickerChange) {
        for c in observers.values {
            c.yield(change)
        }
    }
}
