import Foundation
import Observation
import CoreKit
import Utilities
import AIKit

@MainActor
@Observable
public final class SettingsState {
    public enum TestResult: Equatable, Sendable {
        case ok
        case failure(String)
    }

    public enum LocalModelStatus: Sendable, Hashable {
        case notDownloaded
        case downloading(fraction: Double)
        case ready
    }

    public private(set) var settings: AISettings
    public private(set) var reflection: ReflectionSettings
    public private(set) var biometric: BiometricSettings
    public private(set) var screenShield: ScreenShieldSettings
    public private(set) var sync: SyncSettings
    public private(set) var syncStatus: SyncStatus = .idle
    public private(set) var isSyncing: Bool = false
    public private(set) var isAIAvailable: Bool = false
    public private(set) var isBiometricAvailable: Bool = false
    public private(set) var localModel: LocalModel
    public let localModelCatalog: [LocalModel] = LocalModelCatalog.all
    public var draftRemoteConfig: RemoteConfig
    public var draftAPIKey: String = ""
    public private(set) var isTestingConnection: Bool = false
    public private(set) var testResult: TestResult?
    public private(set) var isKeySaving: Bool = false
    public private(set) var isGeneratingReflection: Bool = false
    public private(set) var reflectionError: String?
    public private(set) var localModelOnDisk: Bool = false
    public private(set) var localModelError: String?
    public private(set) var diagnostics: DiagnosticsSettings

    private let store: AISettingsStore
    private let reflectionStore: ReflectionSettingsStore
    private let biometricStore: BiometricSettingsStore
    private let screenShieldStore: ScreenShieldSettingsStore
    private let syncStore: SyncSettingsStore
    private let diagnosticsStore: DiagnosticsSettingsStore
    private let keychain: AIKeychain
    private let service: AIService
    private let syncService: SyncService
    private let entryRepository: any EntryRepository
    private let insightRepository: any InsightRepository
    private let coordinator: ModelDownloadCoordinator
    private let analyticsService: any AnalyticsService
    private let crashReporter: any CrashReporter

    public init(
        store: AISettingsStore = AISettingsStore(),
        reflectionStore: ReflectionSettingsStore = ReflectionSettingsStore(),
        biometricStore: BiometricSettingsStore = BiometricSettingsStore(),
        screenShieldStore: ScreenShieldSettingsStore = ScreenShieldSettingsStore(),
        syncStore: SyncSettingsStore = SyncSettingsStore(),
        diagnosticsStore: DiagnosticsSettingsStore = DiagnosticsSettingsStore(),
        keychain: AIKeychain = AIKeychain(),
        service: AIService,
        syncService: SyncService = SyncService(),
        entryRepository: any EntryRepository,
        insightRepository: any InsightRepository,
        coordinator: ModelDownloadCoordinator,
        analyticsService: any AnalyticsService,
        crashReporter: any CrashReporter
    ) {
        self.store = store
        self.reflectionStore = reflectionStore
        self.biometricStore = biometricStore
        self.screenShieldStore = screenShieldStore
        self.syncStore = syncStore
        self.diagnosticsStore = diagnosticsStore
        self.keychain = keychain
        self.service = service
        self.syncService = syncService
        self.entryRepository = entryRepository
        self.insightRepository = insightRepository
        self.coordinator = coordinator
        self.analyticsService = analyticsService
        self.crashReporter = crashReporter
        let loaded = store.load()
        self.settings = loaded
        self.reflection = reflectionStore.load()
        self.biometric = biometricStore.load()
        self.screenShield = screenShieldStore.load()
        self.sync = syncStore.load()
        self.diagnostics = diagnosticsStore.load()
        self.draftRemoteConfig = loaded.remote
        let currentID = LocalModelManager.shared.currentModelID
        self.localModel = LocalModelCatalog.model(id: currentID) ?? LocalModelCatalog.default
    }

    // MARK: - Diagnostics

    public func setAnalyticsEnabled(_ enabled: Bool) {
        diagnostics.analyticsEnabled = enabled
        diagnostics.hasAnswered = true
        diagnosticsStore.save(diagnostics)
        analyticsService.setEnabled(enabled)
    }

    public func setCrashReportingEnabled(_ enabled: Bool) {
        diagnostics.crashReportingEnabled = enabled
        diagnostics.hasAnswered = true
        diagnosticsStore.save(diagnostics)
        crashReporter.setEnabled(enabled)
    }

    /// Live download status derived from the coordinator so the UI
    /// reflects progress that started elsewhere (e.g. the dedicated
    /// picker screen) or that survived the app being backgrounded.
    public var localModelStatus: LocalModelStatus {
        switch coordinator.status(for: localModel.id) {
        case .downloading(let fraction):
            return .downloading(fraction: fraction)
        case .ready:
            return .ready
        case .failed:
            return .notDownloaded
        case .idle:
            return localModelOnDisk ? .ready : .notDownloaded
        }
    }

    public func setLocalModel(_ model: LocalModel) async {
        guard model.id != localModel.id else { return }
        coordinator.cancel(localModel.id)
        localModel = model
        localModelError = nil
        LocalModelManager.shared.setCurrentModel(id: model.id)
        await refreshLocalModelStatus()
    }

    public func refresh() async {
        isAIAvailable = await service.isAvailable
        isBiometricAvailable = BiometricAuthService().isAvailable
        draftAPIKey = (try? await keychain.apiKey(for: draftRemoteConfig.provider)) ?? ""
        localModel = LocalModelCatalog.model(id: LocalModelManager.shared.currentModelID) ?? LocalModelCatalog.default
        await refreshLocalModelStatus()
    }

    /// Reloads the active AIService with the current settings snapshot.
    /// Used by downstream screens (e.g. ModelPicker) that mutate on-device
    /// model state but don't own the settings themselves.
    public func reloadAI() async {
        await service.reloadProviders(settings: settings, apiKey: draftAPIKey)
        isAIAvailable = await service.isAvailable
        localModel = LocalModelCatalog.model(id: LocalModelManager.shared.currentModelID) ?? LocalModelCatalog.default
        await refreshLocalModelStatus()
    }

    public func refreshLocalModelStatus() async {
        if case .downloading = coordinator.status(for: localModel.id) { return }
        let downloaded = await LocalModelManager.shared.isDownloaded(localModel)
        localModelOnDisk = downloaded
        if downloaded { coordinator.markReady(localModel.id) }
        if case .failed(let message) = coordinator.status(for: localModel.id) {
            localModelError = message
        }
    }

    public func downloadLocalModel() {
        localModelError = nil
        coordinator.startDownload(localModel)
    }

    public func cancelLocalModelDownload() {
        coordinator.cancel(localModel.id)
    }

    public func removeLocalModel() async {
        do {
            try await LocalModelManager.shared.remove(localModel)
            localModelOnDisk = false
            coordinator.markRemoved(localModel.id)
            await service.reloadProviders(settings: settings, apiKey: remoteKeyForCurrentProvider())
            isAIAvailable = await service.isAvailable
        } catch {
            localModelError = error.localizedDescription
        }
    }

    private func remoteKeyForCurrentProvider() -> String {
        // settings.remote is the active remote config; its API key lives in
        // keychain. The in-memory draftAPIKey is always kept in sync for
        // the selected provider, so reusing it is fine here.
        draftAPIKey
    }

    public func setBiometricMode(_ mode: BiometricMode) {
        var next = biometric
        next.mode = mode
        biometric = next
        biometricStore.save(next)
    }

    public func setScreenShieldEnabled(_ isEnabled: Bool) {
        var next = screenShield
        next.isEnabled = isEnabled
        screenShield = next
        screenShieldStore.save(next)
    }

    public func setSyncEnabled(_ isEnabled: Bool) async {
        if isEnabled {
            // Check the iCloud account before flipping the toggle so
            // users who aren't signed in get a visible reason instead
            // of a silent no-op.
            let status = await syncService.accountStatus()
            guard status == .available else {
                syncStatus = .failed(Self.message(for: status))
                return
            }
        }
        var next = sync
        next.isEnabled = isEnabled
        sync = next
        syncStore.save(next)
        await syncService.setEnabled(isEnabled)
        syncStatus = await syncService.status
    }

    private static func message(for status: CloudKitAccountStatus) -> String {
        switch status {
        case .noAccount:
            String(localized: "Sign in to iCloud in Settings to enable sync.")
        case .restricted:
            String(localized: "iCloud is restricted on this device.")
        case .temporarilyUnavailable:
            String(localized: "iCloud is temporarily unavailable. Try again in a moment.")
        case .couldNotDetermine:
            String(localized: "Couldn't reach iCloud. Try again.")
        case .available:
            ""
        }
    }

    public func syncNow() async {
        guard sync.isEnabled, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        await syncService.sync()
        syncStatus = await syncService.status
    }

    public func exportMarkdown() async -> URL? {
        do {
            let entries = try await entryRepository.fetch(matching: .all)
            return try ExportService().exportMarkdown(entries: entries)
        } catch {
            reflectionError = error.localizedDescription
            return nil
        }
    }

    @MainActor
    public func exportPDF() async -> URL? {
        do {
            let entries = try await entryRepository.fetch(matching: .all)
            return try ExportService().exportPDF(entries: entries)
        } catch {
            reflectionError = error.localizedDescription
            return nil
        }
    }

    public func setReflectionFrequency(_ frequency: ReflectionFrequency) {
        var next = reflection
        next.frequency = frequency
        reflection = next
        reflectionStore.save(next)
        try? BackgroundTaskService().scheduleReflection(for: frequency)
    }

    public func generateReflectionNow(locale: Locale = .autoupdatingCurrent) async {
        guard !isGeneratingReflection else { return }
        isGeneratingReflection = true
        reflectionError = nil
        defer { isGeneratingReflection = false }
        do {
            _ = try await ReflectionService().generate(
                locale: locale,
                aiProvider: service,
                entryRepository: entryRepository,
                insightRepository: insightRepository
            )
        } catch let error as AIError {
            reflectionError = error.errorDescription
        } catch {
            reflectionError = error.localizedDescription
        }
    }

    public func setProvider(_ provider: AISettings.ProviderKind) async {
        var next = settings
        next.provider = provider
        await persist(next, apiKey: draftAPIKey)
    }

    public func setRemoteProvider(_ provider: RemoteConfig.Provider) async {
        var config = draftRemoteConfig
        if config.provider != provider {
            config.provider = provider
            config.model = provider.defaultModel
        }
        draftRemoteConfig = config
        testResult = nil
        draftAPIKey = (try? await keychain.apiKey(for: provider)) ?? ""
        var next = settings
        next.remote = config
        await persist(next, apiKey: draftAPIKey)
    }

    public func setModel(_ model: String) async {
        var config = draftRemoteConfig
        config.model = model
        draftRemoteConfig = config
        var next = settings
        next.remote = config
        await persist(next, apiKey: draftAPIKey)
    }

    public func saveAPIKey() async {
        isKeySaving = true
        defer { isKeySaving = false }
        do {
            if draftAPIKey.isEmpty {
                try await keychain.removeAPIKey(for: draftRemoteConfig.provider)
            } else {
                try await keychain.setAPIKey(draftAPIKey, for: draftRemoteConfig.provider)
            }
        } catch {
            testResult = .failure(error.localizedDescription)
            return
        }
        if settings.provider == .remote {
            await service.reloadProviders(settings: settings, apiKey: draftAPIKey)
            isAIAvailable = await service.isAvailable
        }
    }

    public func testConnection() async {
        isTestingConnection = true
        testResult = nil
        defer { isTestingConnection = false }

        let request = AIRequest(
            messages: [
                AIMessage(role: .user, content: "Reply with the single word OK."),
            ],
            temperature: 0.1,
            maxTokens: 16
        )
        let credentials = RemoteAIProvider.Credentials(
            config: draftRemoteConfig,
            apiKey: draftAPIKey
        )
        let probe = RemoteAIProvider(credentials: credentials)
        do {
            let stream = try await probe.stream(request)
            for try await _ in stream { break }
            testResult = .ok
        } catch let error as AIError {
            testResult = .failure(error.errorDescription ?? String(localized: "Request failed"))
        } catch {
            testResult = .failure(error.localizedDescription)
        }
    }

    private func persist(_ next: AISettings, apiKey: String) async {
        settings = next
        store.save(next)
        await service.reloadProviders(settings: next, apiKey: apiKey)
        isAIAvailable = await service.isAvailable
    }
}
