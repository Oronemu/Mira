import Foundation
import CoreKit

public enum PhotoStorageError: LocalizedError, Sendable {
    case fileNotFound(String)
    case unableToWrite(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            "Photo not found at \(path)."
        case .unableToWrite(let message):
            message
        }
    }
}

/// Stores photo bytes on disk under `<root>/Photos/<uuid>.<ext>`.
/// Bytes never live in SwiftData; the database keeps only the relative
/// path returned here and `PhotoAssetSnapshot` carries it across modules.
public actor PhotoStorageService: PhotoStoring {
    private let directoryURL: URL
    private let directoryName: String

    public init(directoryURL: URL? = nil, directoryName: String = "Photos") throws {
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

    public func save(_ data: Data) async throws -> PhotoAssetSnapshot {
        // User-attached photos get re-encoded through the thumbnail
        // pipeline here — the sync path `save(_:id:)` receives already
        // downsized bytes from CloudKit and must stay lossless.
        let downsized = PhotoDownsizer.downsize(data)
        return try await save(downsized, id: UUID())
    }

    /// Writes `data` to the deterministic file owned by `id`. The sync
    /// puller calls this to materialise a photo downloaded from CloudKit
    /// at the same relative path every device will resolve the photo to.
    public func save(_ data: Data, id: UUID) async throws -> PhotoAssetSnapshot {
        let filename = "\(id.uuidString).jpg"
        let fileURL = directoryURL.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw PhotoStorageError.unableToWrite(error.localizedDescription)
        }
        return PhotoAssetSnapshot(
            id: id,
            relativePath: "\(directoryName)/\(filename)",
            createdAt: .now
        )
    }

    public func exists(relativePath: String) async -> Bool {
        FileManager.default.fileExists(atPath: resolve(relativePath).path)
    }

    public func read(relativePath: String) async throws -> Data {
        let url = resolve(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PhotoStorageError.fileNotFound(relativePath)
        }
        return try Data(contentsOf: url)
    }

    public func delete(relativePath: String) async throws {
        let url = resolve(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    private nonisolated func resolve(_ relativePath: String) -> URL {
        let filename = (relativePath as NSString).lastPathComponent
        return directoryURL.appendingPathComponent(filename)
    }
}
