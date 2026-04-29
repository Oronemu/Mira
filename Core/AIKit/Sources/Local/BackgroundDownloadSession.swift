import Foundation
import os
import Utilities

/// Owns the single `URLSession.background(...)` used for model weight
/// downloads. Background sessions are handed off to the system
/// `nsurlsessiond` daemon and run independently of the app process —
/// they survive app suspension, screen lock, and the process being
/// jetsammed by iOS. When iOS later relaunches the app to deliver
/// completion events, we reattach to the same identifier and the
/// delegate methods fire as if the app had been running the whole time.
///
/// Wiring:
/// 1. `MiraApp.init` touches `BackgroundDownloadSession.shared` so the
///    `URLSession` and its delegate exist before iOS starts replaying
///    delegate events. Doing this lazily is too late — iOS will deliver
///    events the moment the app is relaunched in the background.
/// 2. `AppDelegate` forwards
///    `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
///    to `setBackgroundCompletionHandler(identifier:_:)`.
/// 3. Callers (`ModelDownloadCoordinator`) start downloads via
///    `startDownload(modelID:files:)`, observe progress and outcomes
///    via the closure-based subscriptions.
///
/// Only one model download is active at a time — kicking off a new one
/// while another is in flight returns `.alreadyDownloading`. The
/// per-file URL session tasks themselves can run concurrently.
@MainActor
public final class BackgroundDownloadSession: NSObject {
    public static let shared = BackgroundDownloadSession()

    /// Background `URLSession` identifier. Must be stable across launches —
    /// iOS uses it to reattach in-flight tasks after the app is relaunched.
    public nonisolated static let sessionIdentifier = "com.veilbytesoft.Mira.model-download.urlsession"

    // MARK: - Public types

    public struct PendingFile: Sendable, Hashable {
        public let relativePath: String
        public let url: URL
        public let expectedBytes: Int64
        public let destination: URL

        public init(relativePath: String, url: URL, expectedBytes: Int64, destination: URL) {
            self.relativePath = relativePath
            self.url = url
            self.expectedBytes = expectedBytes
            self.destination = destination
        }
    }

    public enum StartResult: Sendable {
        case started
        case alreadyDownloading(modelID: String)
    }

    public enum Outcome: Sendable {
        case success(modelID: String)
        case failure(modelID: String, message: String)
        case cancelled(modelID: String)
    }

    public struct Progress: Sendable, Equatable {
        public let modelID: String
        public let bytesWritten: Int64
        public let totalExpectedBytes: Int64
        public var fraction: Double {
            totalExpectedBytes > 0 ? Double(bytesWritten) / Double(totalExpectedBytes) : 0
        }
    }

    // MARK: - Public state (read by UI / coordinator)

    /// Snapshot of the currently active download, or `nil`.
    public private(set) var activeProgress: Progress?

    /// Active model identifier. Mirrors `activeProgress?.modelID`.
    public var activeModelID: String? { activeProgress?.modelID }

    // MARK: - Private state (main actor)

    private nonisolated static let log = MiraLog.logger(.models)

    private var session: URLSession!
    private var persistedState: PersistedState?
    private let stateURL: URL

    /// Per-file in-memory tracking. Keyed by `URLSessionDownloadTask.taskIdentifier`.
    private var activeFiles: [Int: ActiveFile] = [:]

    /// Lock-protected mirror used by `nonisolated` delegate callbacks to
    /// look up file metadata without hopping to the main actor — the
    /// `didFinishDownloadingTo` callback must move the temp file before
    /// returning, and we can't `await` for that.
    private let lockedTaskMap = OSAllocatedUnfairLock<[Int: TaskFileInfo]>(initialState: [:])

    private var progressObservers: [UUID: @Sendable (Progress) -> Void] = [:]
    private var outcomeObservers: [UUID: @Sendable (Outcome) -> Void] = [:]

    /// Stored handlers from `application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    /// Keyed by session identifier so we can support more than one in
    /// future without changing the AppDelegate signature.
    private var backgroundCompletionHandlers: [String: () -> Void] = [:]

    private struct ActiveFile {
        let modelID: String
        let relativePath: String
        let destination: URL
        var expectedBytes: Int64
        var bytesWritten: Int64
        var isCompleted: Bool
    }

    private struct TaskFileInfo: Sendable {
        let modelID: String
        let relativePath: String
        let destination: URL
        let expectedBytes: Int64
    }

    // MARK: - Persistence

    private struct PersistedState: Codable, Equatable {
        var modelID: String
        var files: [PersistedFile]

        struct PersistedFile: Codable, Equatable {
            var relativePath: String
            var url: URL
            var destination: URL
            var expectedBytes: Int64
            /// Set when `didFinishDownloadingTo` has fired *and* the
            /// temp file has been moved successfully.
            var isCompleted: Bool
        }
    }

    // MARK: - Init

    private override init() {
        let supportDir = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("mira/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.stateURL = supportDir.appendingPathComponent("background-download.json")

        super.init()

        loadPersistedState()
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true
        // The session is retained by URLSession via its delegate strong
        // reference; this matches Apple's lifecycle for background sessions.
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Reattach to in-flight tasks. Must happen *after* the delegate is
        // wired so events that fire during reattach route to us.
        Task { await self.reattach() }
    }

    // MARK: - Public API

    public func startDownload(
        modelID: String,
        files: [PendingFile]
    ) -> StartResult {
        if let active = activeProgress, active.modelID != modelID {
            return .alreadyDownloading(modelID: active.modelID)
        }
        if let active = activeProgress, active.modelID == modelID {
            // Idempotent: already downloading this model.
            return .started
        }

        // Wipe any leftover persisted state for a different model. Safe
        // because we returned early above if a different one is active.
        persistedState = PersistedState(
            modelID: modelID,
            files: files.map {
                .init(
                    relativePath: $0.relativePath,
                    url: $0.url,
                    destination: $0.destination,
                    expectedBytes: $0.expectedBytes,
                    isCompleted: false
                )
            }
        )
        savePersistedState()

        activeFiles.removeAll()
        lockedTaskMap.withLock { $0.removeAll() }

        let totalExpected = files.reduce(0) { $0 + $1.expectedBytes }
        activeProgress = Progress(
            modelID: modelID,
            bytesWritten: 0,
            totalExpectedBytes: totalExpected
        )
        broadcastProgress()

        for file in files {
            let task = session.downloadTask(with: file.url)
            let info = TaskFileInfo(
                modelID: modelID,
                relativePath: file.relativePath,
                destination: file.destination,
                expectedBytes: file.expectedBytes
            )
            activeFiles[task.taskIdentifier] = ActiveFile(
                modelID: modelID,
                relativePath: file.relativePath,
                destination: file.destination,
                expectedBytes: file.expectedBytes,
                bytesWritten: 0,
                isCompleted: false
            )
            lockedTaskMap.withLock { $0[task.taskIdentifier] = info }
            task.resume()
            Self.log.info("↓ Enqueued \(file.relativePath, privacy: .public) (taskID=\(task.taskIdentifier, privacy: .public)) for \(modelID, privacy: .public)")
        }

        Self.log.info("↓ Background download started • model=\(modelID, privacy: .public) • \(files.count, privacy: .public) files • \(totalExpected, privacy: .public) bytes")
        return .started
    }

    public func cancel(modelID: String) {
        guard activeProgress?.modelID == modelID else { return }
        let identifiersToCancel = activeFiles.keys
        session.getAllTasks { tasks in
            for task in tasks where identifiersToCancel.contains(task.taskIdentifier) {
                task.cancel()
            }
        }
        // Synchronously clear local state so the UI flips immediately.
        // The delegate `didCompleteWithError(.cancelled)` callbacks will
        // arrive shortly and be ignored because state is already cleared.
        finishActiveDownload(outcome: .cancelled(modelID: modelID))
    }

    /// Subscribes to progress updates. Returns a token; pass it to
    /// `removeObserver(_:)` when finished. Idempotent reads of the
    /// current state should use `activeProgress` directly.
    @discardableResult
    public func observeProgress(_ block: @escaping @Sendable (Progress) -> Void) -> UUID {
        let id = UUID()
        progressObservers[id] = block
        return id
    }

    @discardableResult
    public func observeOutcome(_ block: @escaping @Sendable (Outcome) -> Void) -> UUID {
        let id = UUID()
        outcomeObservers[id] = block
        return id
    }

    public func removeObserver(_ id: UUID) {
        progressObservers[id] = nil
        outcomeObservers[id] = nil
    }

    /// Forwarded from `AppDelegate.application(_:handleEventsForBackgroundURLSession:completionHandler:)`.
    /// We store the handler keyed by session identifier and invoke it
    /// from `urlSessionDidFinishEvents(forBackgroundURLSession:)` once
    /// iOS has finished replaying delegate events.
    public func setBackgroundCompletionHandler(
        identifier: String,
        _ handler: @escaping () -> Void
    ) {
        backgroundCompletionHandlers[identifier] = handler
    }

    // MARK: - Reattach

    /// Sync in-memory state with what `nsurlsessiond` actually has in
    /// flight. Called once during init. iOS guarantees that any delegate
    /// events queued for relaunch are delivered before this point — so
    /// any persisted file that's neither in `getAllTasks()` nor marked
    /// completed must have failed silently while we were dead.
    private func reattach() async {
        guard let state = persistedState else { return }
        let liveTasks = await withCheckedContinuation { (cont: CheckedContinuation<[URLSessionDownloadTask], Never>) in
            session.getAllTasks { tasks in
                cont.resume(returning: tasks.compactMap { $0 as? URLSessionDownloadTask })
            }
        }

        // Map live tasks back to persisted files by URL — taskIdentifiers
        // change across launches, so URL is the only stable key.
        var rebuiltActive: [Int: ActiveFile] = [:]
        var rebuiltLocked: [Int: TaskFileInfo] = [:]
        var totalWritten: Int64 = 0
        var hasIncompleteWithoutTask = false

        for file in state.files {
            if file.isCompleted {
                totalWritten += file.expectedBytes
                continue
            }
            if let task = liveTasks.first(where: { $0.originalRequest?.url == file.url }) {
                let info = TaskFileInfo(
                    modelID: state.modelID,
                    relativePath: file.relativePath,
                    destination: file.destination,
                    expectedBytes: file.expectedBytes
                )
                rebuiltActive[task.taskIdentifier] = ActiveFile(
                    modelID: state.modelID,
                    relativePath: file.relativePath,
                    destination: file.destination,
                    expectedBytes: file.expectedBytes,
                    bytesWritten: task.countOfBytesReceived,
                    isCompleted: false
                )
                rebuiltLocked[task.taskIdentifier] = info
                totalWritten += task.countOfBytesReceived
            } else if FileManager.default.fileExists(atPath: file.destination.path) {
                // The file landed on disk while we were dead — the move
                // happened in our delegate during background relaunch but
                // we crashed before persisting. Mark completed.
                if let attrs = try? FileManager.default.attributesOfItem(atPath: file.destination.path),
                   let size = attrs[.size] as? Int64, size > 0 {
                    totalWritten += size
                    if let idx = persistedState?.files.firstIndex(where: { $0.url == file.url }) {
                        persistedState?.files[idx].isCompleted = true
                    }
                }
            } else {
                hasIncompleteWithoutTask = true
            }
        }

        activeFiles = rebuiltActive
        let snapshot = rebuiltLocked
        lockedTaskMap.withLock { $0 = snapshot }

        let totalExpected = state.files.reduce(0) { $0 + $1.expectedBytes }
        if rebuiltActive.isEmpty && hasIncompleteWithoutTask {
            // Nothing in flight, but some files never finished — surface
            // as failure so the UI doesn't sit on stale "downloading".
            Self.log.error("⚠️ Reattach: model=\(state.modelID, privacy: .public) — \(state.files.count - rebuiltActive.count, privacy: .public) files missing without a live task")
            finishActiveDownload(outcome: .failure(
                modelID: state.modelID,
                message: String(localized: "Download was interrupted. Tap to retry.")
            ))
            return
        }

        if rebuiltActive.isEmpty && persistedState?.files.allSatisfy({ $0.isCompleted }) == true {
            // Everything completed while dead — emit success.
            activeProgress = Progress(
                modelID: state.modelID,
                bytesWritten: totalExpected,
                totalExpectedBytes: totalExpected
            )
            broadcastProgress()
            savePersistedState()
            Self.log.info("✓ Reattach: \(state.modelID, privacy: .public) finished while dead")
            finishActiveDownload(outcome: .success(modelID: state.modelID))
            return
        }

        if !rebuiltActive.isEmpty {
            activeProgress = Progress(
                modelID: state.modelID,
                bytesWritten: totalWritten,
                totalExpectedBytes: totalExpected
            )
            broadcastProgress()
            Self.log.info("↻ Reattach: \(state.modelID, privacy: .public) • \(rebuiltActive.count, privacy: .public) live • \(totalWritten, privacy: .public)/\(totalExpected, privacy: .public) bytes")
        }
        savePersistedState()
    }

    // MARK: - Internals (main-actor only)

    private func updateProgress(taskIdentifier: Int, bytesWritten: Int64, totalForFile: Int64) {
        guard var file = activeFiles[taskIdentifier] else { return }
        file.bytesWritten = bytesWritten
        // Patch expected size if the server reported a different value
        // than our HEAD-derived estimate (Hub LFS can drift).
        if totalForFile > 0, totalForFile != file.expectedBytes {
            file.expectedBytes = totalForFile
            if let idx = persistedState?.files.firstIndex(where: { $0.relativePath == file.relativePath }) {
                persistedState?.files[idx].expectedBytes = totalForFile
            }
        }
        activeFiles[taskIdentifier] = file

        let written = activeFiles.values.reduce(0) { $0 + $1.bytesWritten }
        let total = max(written, activeFiles.values.reduce(0) { $0 + $1.expectedBytes }
            + (persistedState?.files.filter(\.isCompleted).reduce(0) { $0 + $1.expectedBytes } ?? 0))
        if let modelID = activeProgress?.modelID {
            activeProgress = Progress(
                modelID: modelID,
                bytesWritten: written + (persistedState?.files.filter(\.isCompleted).reduce(0) { $0 + $1.expectedBytes } ?? 0),
                totalExpectedBytes: total
            )
            broadcastProgress()
        }
    }

    private func handleFileFinished(taskIdentifier: Int, success: Bool) {
        guard var file = activeFiles[taskIdentifier] else { return }
        if success {
            file.isCompleted = true
            file.bytesWritten = file.expectedBytes
            activeFiles[taskIdentifier] = file

            if let idx = persistedState?.files.firstIndex(where: { $0.relativePath == file.relativePath }) {
                persistedState?.files[idx].isCompleted = true
            }
            savePersistedState()
            lockedTaskMap.withLock { $0[taskIdentifier] = nil }

            // Remove from active map once committed.
            activeFiles[taskIdentifier] = nil

            let allDone = persistedState?.files.allSatisfy(\.isCompleted) ?? false
            if allDone, let modelID = activeProgress?.modelID {
                let total = persistedState?.files.reduce(0) { $0 + $1.expectedBytes } ?? 0
                activeProgress = Progress(modelID: modelID, bytesWritten: total, totalExpectedBytes: total)
                broadcastProgress()
                finishActiveDownload(outcome: .success(modelID: modelID))
            } else {
                broadcastProgress()
            }
        } else if let modelID = activeProgress?.modelID {
            // The move failed — fail the whole download.
            failAllAndFinish(modelID: modelID, message: String(localized: "Could not save downloaded file."))
        }
    }

    private func handleFileError(taskIdentifier: Int, error: Error) {
        let nsError = error as NSError
        // Cancelled tasks fire here too. If we're already past the
        // active state (cancel was called), drop silently.
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            lockedTaskMap.withLock { $0[taskIdentifier] = nil }
            activeFiles[taskIdentifier] = nil
            return
        }
        guard let modelID = activeProgress?.modelID else { return }
        Self.log.error("✗ File task \(taskIdentifier, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        failAllAndFinish(modelID: modelID, message: error.localizedDescription)
    }

    private func failAllAndFinish(modelID: String, message: String) {
        let identifiersToCancel = activeFiles.keys
        session.getAllTasks { tasks in
            for task in tasks where identifiersToCancel.contains(task.taskIdentifier) {
                task.cancel()
            }
        }
        finishActiveDownload(outcome: .failure(modelID: modelID, message: message))
    }

    private func finishActiveDownload(outcome: Outcome) {
        activeProgress = nil
        activeFiles.removeAll()
        lockedTaskMap.withLock { $0.removeAll() }
        persistedState = nil
        deletePersistedState()
        broadcastOutcome(outcome)
    }

    private func broadcastProgress() {
        guard let p = activeProgress else { return }
        for cb in progressObservers.values { cb(p) }
    }

    private func broadcastOutcome(_ o: Outcome) {
        for cb in outcomeObservers.values { cb(o) }
    }

    private func loadPersistedState() {
        guard let data = try? Data(contentsOf: stateURL) else { return }
        persistedState = try? JSONDecoder().decode(PersistedState.self, from: data)
        if let state = persistedState {
            let total = state.files.reduce(0) { $0 + $1.expectedBytes }
            let done = state.files.filter(\.isCompleted).reduce(0) { $0 + $1.expectedBytes }
            activeProgress = Progress(modelID: state.modelID, bytesWritten: done, totalExpectedBytes: total)
        }
    }

    private func savePersistedState() {
        guard let state = persistedState else {
            deletePersistedState()
            return
        }
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            Self.log.error("Failed to save background download state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deletePersistedState() {
        try? FileManager.default.removeItem(at: stateURL)
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundDownloadSession: URLSessionDownloadDelegate {
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let id = downloadTask.taskIdentifier
        Task { @MainActor in
            self.updateProgress(
                taskIdentifier: id,
                bytesWritten: totalBytesWritten,
                totalForFile: totalBytesExpectedToWrite
            )
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // CRITICAL: iOS deletes `location` the moment this callback
        // returns. We must move the temp file to its destination
        // synchronously here, before any await.
        let id = downloadTask.taskIdentifier
        guard let info = lockedTaskMap.withLock({ $0[id] }) else { return }

        var moved = false
        do {
            let parent = info.destination.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: info.destination.path) {
                try FileManager.default.removeItem(at: info.destination)
            }
            try FileManager.default.moveItem(at: location, to: info.destination)
            moved = true
        } catch {
            Self.log.error("✗ Failed to move \(info.relativePath, privacy: .public) to destination: \(error.localizedDescription, privacy: .public)")
        }

        Task { @MainActor in
            self.handleFileFinished(taskIdentifier: id, success: moved)
        }
    }

    public nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Success path is handled in `didFinishDownloadingTo`. Only act
        // on errors here.
        guard let error else { return }
        let id = task.taskIdentifier
        Task { @MainActor in
            self.handleFileError(taskIdentifier: id, error: error)
        }
    }

    public nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let identifier = session.configuration.identifier ?? Self.sessionIdentifier
        Task { @MainActor in
            // Apple requires the completion handler to be invoked on the
            // main thread.
            let handler = self.backgroundCompletionHandlers.removeValue(forKey: identifier)
            handler?()
        }
    }
}
