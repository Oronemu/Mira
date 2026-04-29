import Foundation
import Observation
import AIKit

@MainActor
@Observable
public final class ModelPickerState {
    public enum ModelStatus: Sendable, Hashable {
        case notDownloaded
        case downloading(fraction: Double)
        case ready
    }

    public let catalog: [LocalModel] = LocalModelCatalog.all
    public private(set) var currentModelID: String

    /// On-disk presence, resolved by `refresh()`. The "downloading" status
    /// is not stored here — it's read live from the coordinator.
    public private(set) var onDiskReady: [String: Bool] = [:]
    public private(set) var errors: [String: String] = [:]

    private let coordinator: ModelDownloadCoordinator

    /// Fired after any state-changing action (select / remove). Download
    /// completion is wired inside `ServiceContainer` and doesn't need to
    /// re-invoke this callback.
    private let reloadService: @Sendable () async -> Void

    public init(
        coordinator: ModelDownloadCoordinator,
        reloadService: @escaping @Sendable () async -> Void = {}
    ) {
        self.coordinator = coordinator
        self.reloadService = reloadService
        self.currentModelID = LocalModelManager.shared.currentModelID
    }

    // MARK: - Derived

    public var activeDownloadID: String? {
        catalog.first { model in
            if case .downloading = coordinator.status(for: model.id) { return true }
            return false
        }?.id
    }

    public func isCurrent(_ model: LocalModel) -> Bool {
        model.id == currentModelID
    }

    public func status(of model: LocalModel) -> ModelStatus {
        switch coordinator.status(for: model.id) {
        case .downloading(let fraction):
            return .downloading(fraction: fraction)
        case .ready:
            return .ready
        case .failed:
            return .notDownloaded
        case .idle:
            return (onDiskReady[model.id] ?? false) ? .ready : .notDownloaded
        }
    }

    // MARK: - Refresh

    public func refresh() async {
        for model in catalog {
            switch coordinator.status(for: model.id) {
            case .downloading:
                continue
            case .failed(let message):
                errors[model.id] = message
            case .idle, .ready:
                errors[model.id] = nil
            }
            let downloaded = await LocalModelManager.shared.isDownloaded(model)
            onDiskReady[model.id] = downloaded
            if downloaded { coordinator.markReady(model.id) }
        }
    }

    // MARK: - Mutations

    public func select(_ model: LocalModel) async {
        guard model.id != currentModelID else { return }
        currentModelID = model.id
        LocalModelManager.shared.setCurrentModel(id: model.id)
        await reloadService()
    }

    public func download(_ model: LocalModel) {
        errors[model.id] = nil
        coordinator.startDownload(model)
    }

    public func cancelActiveDownload() {
        guard let id = activeDownloadID else { return }
        coordinator.cancel(id)
    }

    public func remove(_ model: LocalModel) async {
        do {
            try await LocalModelManager.shared.remove(model)
            onDiskReady[model.id] = false
            coordinator.markRemoved(model.id)
            errors[model.id] = nil
            if model.id == currentModelID {
                await reloadService()
            }
        } catch {
            errors[model.id] = error.localizedDescription
        }
    }
}
