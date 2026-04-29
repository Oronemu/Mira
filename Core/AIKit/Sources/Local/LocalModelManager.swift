import Foundation
import os
@preconcurrency import Hub
import CoreKit
import Utilities

/// Owns on-device model storage. Downloads themselves run inside
/// `BackgroundDownloadSession` (a system-managed background URLSession);
/// this type only knows how to enumerate the files a model needs and
/// how to finalize the model once all files have arrived.
///
/// `HubApi` is still used for two narrow foreground operations:
/// * `getFilenames` — list files in the repo (single small JSON GET).
/// * `getFileMetadata` — HEAD per file to learn expected size + the
///   redirected CDN location URL we hand to `URLSessionDownloadTask`.
public actor LocalModelManager {
    public static let shared = LocalModelManager()

    private static let log = MiraLog.logger(.models)
    private static let currentIDKey = "local.model.current"
    /// Sentinel file written inside a model's directory once every file
    /// has been verified on disk. `isDownloaded` only returns true when
    /// this marker is present — partial downloads (interrupted by a
    /// cancellation or by a process kill mid-flight) sit on disk
    /// without being misreported as a completed model.
    private static let completionMarker = ".mira-download-complete"
    private let hubApi: HubApi

    public init() {
        self.hubApi = HubApi(downloadBase: Self.baseURL())
    }

    public nonisolated var currentModelID: String {
        UserDefaults.standard.string(forKey: Self.currentIDKey) ?? LocalModelCatalog.defaultModelID
    }

    public nonisolated func setCurrentModel(id: String) {
        UserDefaults.standard.set(id, forKey: Self.currentIDKey)
    }

    public func isDownloaded(_ model: LocalModel) -> Bool {
        let marker = Self.modelDirectory(for: model).appendingPathComponent(Self.completionMarker)
        return FileManager.default.fileExists(atPath: marker.path)
    }

    public func remove(_ model: LocalModel) throws {
        let url = Self.modelDirectory(for: model)
        if FileManager.default.fileExists(atPath: url.path) {
            Self.log.info("Removing model \(model.id, privacy: .public) from \(url.path, privacy: .public)")
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                let nsError = error as NSError
                Self.log.error("Failed to remove model \(model.id, privacy: .public): \(error.localizedDescription, privacy: .public) • domain=\(nsError.domain, privacy: .public) • code=\(nsError.code, privacy: .public)")
                throw error
            }
        }
    }

    public func location(of model: LocalModel) -> URL {
        Self.modelDirectory(for: model)
    }

    /// Exposed so `MLXLocalProvider` and anything else that talks to
    /// the Hub shares the same download base directory.
    public var hub: HubApi { hubApi }

    /// Resolves the file list for a model into per-file download
    /// descriptors that `BackgroundDownloadSession` knows how to
    /// enqueue. Performs network I/O (one list + N HEADs) so call from
    /// foreground only.
    public func prepareFiles(for model: LocalModel) async throws -> [BackgroundDownloadSession.PendingFile] {
        let api = HubApi(downloadBase: Self.baseURL())
        let repo = Hub.Repo(id: model.huggingFaceRepo)
        let filenames = try await api.getFilenames(
            from: repo,
            matching: ["*.safetensors", "*.json", "*.txt", "*.model"]
        )
        guard !filenames.isEmpty else {
            throw AIError.downloadIncomplete(completed: 0, total: 0)
        }

        let modelDir = Self.modelDirectory(for: model)
        let endpoint = "https://huggingface.co"

        // Parallelize HEAD requests — sequential is ~200 ms per file
        // which adds up on multi-shard models.
        let metadata = try await withThrowingTaskGroup(of: (String, BackgroundDownloadSession.PendingFile).self) { group in
            for filename in filenames {
                group.addTask {
                    guard let publicURL = URL(string: "\(endpoint)/\(model.huggingFaceRepo)/resolve/main/\(filename)") else {
                        throw AIError.downloadIncomplete(completed: 0, total: 1)
                    }
                    let meta = try await api.getFileMetadata(url: publicURL)
                    let size = Int64(meta.size ?? 0)
                    let pending = BackgroundDownloadSession.PendingFile(
                        relativePath: filename,
                        url: publicURL,
                        expectedBytes: size,
                        destination: modelDir.appendingPathComponent(filename)
                    )
                    return (filename, pending)
                }
            }
            var collected: [(String, BackgroundDownloadSession.PendingFile)] = []
            for try await item in group { collected.append(item) }
            return collected
        }

        // Preserve the original order returned by getFilenames so
        // logging stays readable.
        let byName = Dictionary(uniqueKeysWithValues: metadata)
        let ordered = filenames.compactMap { byName[$0] }

        let totalBytes = ordered.reduce(Int64(0)) { $0 + $1.expectedBytes }
        Self.log.info("↓ Prepared \(ordered.count, privacy: .public) files for \(model.id, privacy: .public) • \(totalBytes, privacy: .public) bytes")
        return ordered
    }

    /// Writes the completion marker after every file has landed on
    /// disk. Idempotent — calling twice is harmless.
    public func markComplete(_ model: LocalModel) throws {
        let dir = Self.modelDirectory(for: model)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let markerURL = dir.appendingPathComponent(Self.completionMarker)
        try Data().write(to: markerURL)
        Self.log.info("✓ Marked \(model.id, privacy: .public) complete")
    }

    private static func baseURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = root.appendingPathComponent("mira/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func modelDirectory(for model: LocalModel) -> URL {
        let parts = model.huggingFaceRepo.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return baseURL() }
        return baseURL()
            .appendingPathComponent("models/\(parts[0])/\(parts[1])", isDirectory: true)
    }
}
