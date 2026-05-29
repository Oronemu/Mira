import Foundation
import CoreKit

public enum CustomStickerStorageError: LocalizedError, Sendable {
    case fileNotFound(String)
    case unableToWrite(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            "Custom sticker not found at \(path)."
        case .unableToWrite(let message):
            message
        }
    }
}

/// Stores user-created sticker PNGs at `<root>/Stickers/<uuid>.png`.
/// Mirrors `PhotoStorageService` so the sync push/pull layer can treat
/// both blob types the same way. Bytes never live in SwiftData — the
/// renderer resolves `"user:<uuid>"` libraryRefs through the
/// `CustomStickerStoring` environment and pulls bytes from this actor.
public actor CustomStickerStorageService: CustomStickerStoring {
    private let directoryURL: URL
    private let directoryName: String

    /// Observers fan out create/delete events to subscribed pushers.
    /// Plain dictionary, not weakly held — `AsyncStream.Continuation`'s
    /// onTermination callback is responsible for cleanup.
    private var observers: [UUID: AsyncStream<CustomStickerChange>.Continuation] = [:]

    public init(directoryURL: URL? = nil, directoryName: String = "Stickers") throws {
        self.directoryName = directoryName
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.directoryURL = documents.appendingPathComponent(directoryName, isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
    }

    public func save(_ pngData: Data) async throws -> CustomStickerAsset {
        try await save(pngData, id: UUID(), createdAt: .now)
    }

    @discardableResult
    public func save(_ pngData: Data, id: UUID, createdAt: Date) async throws -> CustomStickerAsset {
        let filename = "\(id.uuidString).png"
        let fileURL = directoryURL.appendingPathComponent(filename)
        do {
            try pngData.write(to: fileURL, options: .atomic)
        } catch {
            throw CustomStickerStorageError.unableToWrite(error.localizedDescription)
        }
        let asset = CustomStickerAsset(
            id: id,
            relativePath: "\(directoryName)/\(filename)",
            createdAt: createdAt
        )
        emit(.upserted(asset))
        return asset
    }

    public func exists(id: UUID) async -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: id).path)
    }

    public func read(relativePath: String) async throws -> Data {
        let url = resolve(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CustomStickerStorageError.fileNotFound(relativePath)
        }
        return try Data(contentsOf: url)
    }

    public func delete(id: UUID) async throws {
        try? FileManager.default.removeItem(at: fileURL(for: id))
        emit(.deleted(id))
    }

    public func list() async throws -> [CustomStickerAsset] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let assets: [CustomStickerAsset] = urls.compactMap { url in
            guard url.pathExtension.lowercased() == "png" else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            guard let id = UUID(uuidString: name) else { return nil }
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return CustomStickerAsset(
                id: id,
                relativePath: "\(directoryName)/\(url.lastPathComponent)",
                createdAt: created
            )
        }
        return assets.sorted { $0.createdAt > $1.createdAt }
    }

    public nonisolated func changes() -> AsyncStream<CustomStickerChange> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.registerObserver(token: token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterObserver(token: token) }
            }
        }
    }

    // MARK: - Internals

    private func registerObserver(
        token: UUID,
        continuation: AsyncStream<CustomStickerChange>.Continuation
    ) {
        observers[token] = continuation
    }

    private func unregisterObserver(token: UUID) {
        observers.removeValue(forKey: token)
    }

    private func emit(_ change: CustomStickerChange) {
        for continuation in observers.values {
            continuation.yield(change)
        }
    }

    private nonisolated func fileURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).png")
    }

    private nonisolated func resolve(_ relativePath: String) -> URL {
        let filename = (relativePath as NSString).lastPathComponent
        return directoryURL.appendingPathComponent(filename)
    }
}
