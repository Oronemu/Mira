import Foundation
import Observation
import Utilities

/// Observable façade in front of `BackgroundDownloadSession`. The UI
/// reads `status(for:)`; SwiftUI re-renders because this class is
/// `@Observable`. Actual byte movement happens in the system
/// `nsurlsessiond` daemon and survives app suspension / kill — see
/// `BackgroundDownloadSession` for the wiring.
///
/// Only one model can be downloading at a time. Starting a download
/// while another is in flight returns `.failed` on the second model.
@MainActor
@Observable
public final class ModelDownloadCoordinator {
    public enum DownloadStatus: Sendable, Hashable {
        case idle
        case downloading(fraction: Double)
        case ready
        case failed(message: String)
    }

    public private(set) var statuses: [String: DownloadStatus] = [:]

    private let manager: LocalModelManager
    private let session: BackgroundDownloadSession
    private let didFinishDownload: @Sendable (LocalModel, Bool) async -> Void

    private var progressToken: UUID?
    private var outcomeToken: UUID?

    private nonisolated static let log = MiraLog.logger(.models)

    public init(
        manager: LocalModelManager = .shared,
        session: BackgroundDownloadSession = .shared,
        didFinishDownload: @escaping @Sendable (LocalModel, Bool) async -> Void = { _, _ in }
    ) {
        self.manager = manager
        self.session = session
        self.didFinishDownload = didFinishDownload

        // Hydrate initial state from whatever the session reattached
        // to during its own init (e.g. cold launch with a download
        // already in flight via nsurlsessiond).
        if let active = session.activeProgress {
            statuses[active.modelID] = .downloading(fraction: active.fraction)
        }

        progressToken = session.observeProgress { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.statuses[progress.modelID] = .downloading(fraction: progress.fraction)
            }
        }
        outcomeToken = session.observeOutcome { [weak self] outcome in
            Task { @MainActor [weak self] in
                await self?.handleOutcome(outcome)
            }
        }
    }

    // The coordinator is a singleton owned by `ServiceContainer` for
    // the lifetime of the app — no deinit cleanup needed.

    // MARK: - Public API

    public func status(for modelID: String) -> DownloadStatus {
        statuses[modelID] ?? .idle
    }

    public var hasActiveDownload: Bool {
        statuses.values.contains { if case .downloading = $0 { return true } else { return false } }
    }

    /// Submit a download. Idempotent for the same model. Returns a
    /// `.failed` status on the passed model if a different one is
    /// already in flight (only one can run at a time).
    public func startDownload(_ model: LocalModel) {
        if case .downloading = statuses[model.id] { return }
        if hasActiveDownload {
            statuses[model.id] = .failed(
                message: String(localized: "Another download is already in progress.")
            )
            return
        }

        statuses[model.id] = .downloading(fraction: 0)
        Task { [weak self] in
            await self?.beginDownload(model)
        }
    }

    public func cancel(_ modelID: String) {
        session.cancel(modelID: modelID)
        statuses[modelID] = .idle
    }

    /// Called after the user deletes the model from disk.
    public func markRemoved(_ modelID: String) {
        statuses[modelID] = .idle
    }

    /// Called after an initial existence check determines the model is
    /// already downloaded.
    public func markReady(_ modelID: String) {
        statuses[modelID] = .ready
    }

    // MARK: - Private

    private func beginDownload(_ model: LocalModel) async {
        do {
            let files = try await manager.prepareFiles(for: model)
            let result = session.startDownload(modelID: model.id, files: files)
            switch result {
            case .started:
                Self.log.info("↓ Background download started for \(model.id, privacy: .public)")
            case .alreadyDownloading(let other):
                statuses[model.id] = .failed(
                    message: String(format: String(localized: "Already downloading %@."), other)
                )
            }
        } catch {
            Self.log.error("✗ prepareFiles failed for \(model.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            statuses[model.id] = .failed(message: error.localizedDescription)
        }
    }

    private func handleOutcome(_ outcome: BackgroundDownloadSession.Outcome) async {
        switch outcome {
        case .success(let modelID):
            guard let model = LocalModelCatalog.model(id: modelID) else { return }
            do {
                try await manager.markComplete(model)
                statuses[modelID] = .ready
                Self.log.info("✓ Download completed for \(modelID, privacy: .public)")
                await didFinishDownload(model, true)
            } catch {
                statuses[modelID] = .failed(message: error.localizedDescription)
                await didFinishDownload(model, false)
            }
        case .failure(let modelID, let message):
            statuses[modelID] = .failed(message: message)
            if let model = LocalModelCatalog.model(id: modelID) {
                await didFinishDownload(model, false)
            }
        case .cancelled(let modelID):
            statuses[modelID] = .idle
            if let model = LocalModelCatalog.model(id: modelID) {
                await didFinishDownload(model, false)
            }
        }
    }
}
