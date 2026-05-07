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

    /// Resolves a stored model ID into a runnable `LocalModel`,
    /// supporting both catalog entries and orphan picks. The provider
    /// uses this instead of `LocalModelCatalog` directly so a
    /// `legacy:<org>/<repo>` selection actually loads.
    public func resolveModel(id: String) -> LocalModel? {
        if let catalogModel = LocalModelCatalog.model(id: id) {
            return catalogModel
        }
        let prefix = "legacy:"
        guard id.hasPrefix(prefix) else { return nil }
        let repoPath = String(id.dropFirst(prefix.count))
        let parts = repoPath.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return nil }
        let dir = Self.baseURL().appendingPathComponent("models/\(parts[0])/\(parts[1])", isDirectory: true)
        let marker = dir.appendingPathComponent(Self.completionMarker)
        guard FileManager.default.fileExists(atPath: marker.path) else { return nil }
        let bytes = Self.directorySize(at: dir)
        // Estimate RAM from disk weights — 4-bit quantised models need
        // roughly 2× the weight size at runtime for KV cache + scratch.
        let gb = max(8, Int(ceil(Double(bytes) * 2 / 1_073_741_824)))
        return LocalModel(
            id: id,
            displayName: parts[1],
            huggingFaceRepo: repoPath,
            sizeBytes: bytes,
            minimumRAMGB: gb,
            description: "",
            highlights: []
        )
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

    /// A completed download whose HuggingFace repo no longer matches any
    /// entry in `LocalModelCatalog`. Surfaced in Settings so the user can
    /// reclaim the disk space when the catalog rolls forward.
    public struct OrphanedDownload: Sendable, Hashable, Identifiable {
        /// `legacy:<org>/<repo>` — distinct from any catalog id so it
        /// can't be confused with a current model in stored preferences.
        public let id: String
        /// HF repo path, e.g. `mlx-community/Qwen3-4B-Instruct-2507-4bit`.
        public let huggingFaceRepo: String
        /// Best-effort display name — the repo name with quantization
        /// suffix preserved so users can tell variants apart.
        public let displayName: String
        public let sizeBytes: Int64

        public init(huggingFaceRepo: String, sizeBytes: Int64) {
            self.id = "legacy:\(huggingFaceRepo)"
            self.huggingFaceRepo = huggingFaceRepo
            self.displayName = huggingFaceRepo.split(separator: "/").last.map(String.init) ?? huggingFaceRepo
            self.sizeBytes = sizeBytes
        }
    }

    /// Walks the on-disk model store, returns directories that look like
    /// fully-completed downloads (have the completion marker) but whose
    /// repo path is not in `LocalModelCatalog.all.huggingFaceRepo`.
    /// Partial downloads are skipped — they get cleaned up the next time
    /// the user retries the same model.
    public func discoverOrphans() -> [OrphanedDownload] {
        let fm = FileManager.default
        let modelsRoot = Self.baseURL().appendingPathComponent("models", isDirectory: true)
        guard fm.fileExists(atPath: modelsRoot.path) else { return [] }

        let knownRepos = Set(LocalModelCatalog.all.map(\.huggingFaceRepo))
        var orphans: [OrphanedDownload] = []

        let orgDirs = (try? fm.contentsOfDirectory(at: modelsRoot, includingPropertiesForKeys: nil)) ?? []
        for orgDir in orgDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: orgDir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let repoDirs = (try? fm.contentsOfDirectory(at: orgDir, includingPropertiesForKeys: nil)) ?? []
            for repoDir in repoDirs {
                var isRepoDir: ObjCBool = false
                guard fm.fileExists(atPath: repoDir.path, isDirectory: &isRepoDir), isRepoDir.boolValue else { continue }
                let marker = repoDir.appendingPathComponent(Self.completionMarker)
                guard fm.fileExists(atPath: marker.path) else { continue }
                let repoPath = "\(orgDir.lastPathComponent)/\(repoDir.lastPathComponent)"
                guard !knownRepos.contains(repoPath) else { continue }
                let bytes = Self.directorySize(at: repoDir)
                orphans.append(OrphanedDownload(huggingFaceRepo: repoPath, sizeBytes: bytes))
            }
        }

        return orphans.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    /// Deletes an orphan's on-disk files. Called from the Settings
    /// "Old downloads" screen.
    public func remove(orphan: OrphanedDownload) throws {
        let parts = orphan.huggingFaceRepo.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return }
        let dir = Self.baseURL().appendingPathComponent("models/\(parts[0])/\(parts[1])", isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else { return }
        Self.log.info("Removing orphan \(orphan.huggingFaceRepo, privacy: .public)")
        try FileManager.default.removeItem(at: dir)
    }

    private static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true, let size = values?.fileSize {
                total += Int64(size)
            }
        }
        return total
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
