import Foundation
import Observation
import AIKit
import CoreKit

@MainActor
@Observable
public final class LegacyDownloadsState {
    public private(set) var orphans: [LocalModelManager.OrphanedDownload] = []
    public private(set) var currentModelID: String
    public private(set) var errorMessage: String?
    public private(set) var isLoading: Bool = false

    private let analyticsService: any AnalyticsService
    private let crashReporter: any CrashReporter
    private let reloadService: @Sendable () async -> Void

    public init(
        analyticsService: any AnalyticsService = UnimplementedAnalyticsService(),
        crashReporter: any CrashReporter = UnimplementedCrashReporter(),
        reloadService: @escaping @Sendable () async -> Void = {}
    ) {
        self.analyticsService = analyticsService
        self.crashReporter = crashReporter
        self.reloadService = reloadService
        self.currentModelID = LocalModelManager.shared.currentModelID
    }

    public func isCurrent(_ orphan: LocalModelManager.OrphanedDownload) -> Bool {
        orphan.id == currentModelID
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        orphans = await LocalModelManager.shared.discoverOrphans()
        currentModelID = LocalModelManager.shared.currentModelID
    }

    /// Marks an orphan as the active local model. The MLX provider
    /// resolves `legacy:<repo>` IDs through `LocalModelManager.resolveModel`
    /// and loads the on-disk snapshot directly.
    public func use(_ orphan: LocalModelManager.OrphanedDownload) async {
        guard orphan.id != currentModelID else { return }
        currentModelID = orphan.id
        LocalModelManager.shared.setCurrentModel(id: orphan.id)
        await reloadService()
        analyticsService.log(
            event: "legacy_model_selected",
            parameters: ["repo": .string(orphan.huggingFaceRepo)]
        )
    }

    public func remove(_ orphan: LocalModelManager.OrphanedDownload) async {
        do {
            try await LocalModelManager.shared.remove(orphan: orphan)
            orphans.removeAll { $0.id == orphan.id }
            // If the removed orphan was the active model, fall back to
            // the catalog default so AskMira doesn't keep pointing at a
            // dead path.
            if orphan.id == currentModelID {
                LocalModelManager.shared.setCurrentModel(id: LocalModelCatalog.defaultModelID)
                currentModelID = LocalModelCatalog.defaultModelID
                await reloadService()
            }
            analyticsService.log(
                event: "legacy_model_removed",
                parameters: ["repo": .string(orphan.huggingFaceRepo)]
            )
        } catch {
            errorMessage = error.localizedDescription
            crashReporter.recordError(error, reason: "legacy_downloads.remove")
        }
    }
}
