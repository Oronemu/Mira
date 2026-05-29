import SwiftUI
import BackgroundTasks
import WidgetKit
import CoreKit
import AIKit
import Utilities
import DesignSystem
import Telemetry
import FeatureOnboarding
import FeaturePaywall

@main
struct MiraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container: ServiceContainer
    @State private var lockState = LockState()
    @State private var appearanceState = AppearanceState()
    @State private var paywallPresenter: AppPaywallPresenter
    @State private var hasOnboarded: Bool = OnboardingStore().isCompleted
    @State private var screenShieldEnabled: Bool = ScreenShieldSettingsStore().load().isEnabled
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Firebase must be configured before any Firebase SDK is touched,
        // including the service implementations built inside `live()`.
        FirebaseBootstrap.configure()
        let container = ServiceContainer.live()
        _container = State(initialValue: container)
        _paywallPresenter = State(
            initialValue: AppPaywallPresenter(analyticsService: container.analyticsService)
        )
        // Apply the user's diagnostics consent. Info.plist defaults both
        // Analytics and Crashlytics to OFF, so without this call Firebase
        // stays silent. The runtime flip happens synchronously in init to
        // avoid any window where automatic collection could fire before
        // consent has been applied.
        let diagnostics = DiagnosticsSettingsStore().load()
        if diagnostics.hasAnswered {
            container.analyticsService.setEnabled(diagnostics.analyticsEnabled)
            container.crashReporter.setEnabled(diagnostics.crashReportingEnabled)
        }
        registerBackgroundTasks(container: container)
        // Touch the background URL session singleton so its delegate
        // exists *before* iOS replays any queued
        // `URLSession.background` events. Doing this lazily is too
        // late — the events arrive between AppDelegate setup and the
        // first scene update.
        _ = BackgroundDownloadSession.shared
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasOnboarded {
                    RootView()
                        .environment(\.entryRepository, container.entryRepository)
                        .environment(\.insightRepository, container.insightRepository)
                        .environment(\.askMiraRepository, container.askMiraRepository)
                        .environment(\.aiProvider, container.aiProvider)
                        .environment(\.aiService, container.aiService)
                        .environment(\.embeddingProvider, container.embeddingProvider)
                        .environment(\.photoStoring, container.photoStoring)
                        .environment(\.customStickerStore, container.customStickerStore)
                        .environment(\.analyticsService, container.analyticsService)
                        .environment(\.crashReporter, container.crashReporter)
                        .environment(\.pushNotificationService, container.pushNotificationService)
                        .environment(\.remoteConfigService, container.remoteConfigService)
                        .environment(\.legalLinks, container.legalLinks)
                        .environment(\.modelDownloadCoordinator, container.modelDownloadCoordinator)
                        .environment(\.syncService, container.syncService)
                        .environment(\.subscriptionService, container.subscriptionService)
                        .environment(\.paywallPresenter, paywallPresenter)
                        .sheet(item: Binding(
                            get: { paywallPresenter.pendingContext },
                            set: { _ in paywallPresenter.dismiss() }
                        )) { context in
                            PaywallView(context: context)
                                .environment(\.subscriptionService, container.subscriptionService)
                        }
                    if lockState.isLocked {
                        LockScreenView(state: lockState)
                            .transition(.opacity)
                    }
                    if shouldShowShield && !lockState.isLocked {
                        PrivacyShieldView()
                            .transition(.opacity)
                    }
                } else {
                    OnboardingView {
                        OnboardingStore().isCompleted = true
                        withAnimation { hasOnboarded = true }
                    }
                    .transition(.opacity)
                }
            }
            .environment(\.appearanceState, appearanceState)
            .preferredColorScheme(appearanceState.colorScheme)
            .tint(MiraPalette.tintColor(for: appearanceState.settings))
            .task { bootstrapTelemetry() }
            .task { await bootstrapRemoteKey() }
            .task { await backfillEmbeddings() }
            .task { await bootstrapNotifications() }
            .task { await bootstrapLocalNotifications() }
            .task { await bootstrapSync() }
            .task { await syncProEntitlementToWidgets() }
            .onChange(of: scenePhase) { _, newPhase in
                lockState.handle(scenePhase: newPhase)
                if newPhase == .active {
                    screenShieldEnabled = ScreenShieldSettingsStore().load().isEnabled
                    Task { await bootstrapLocalNotifications() }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: shouldShowShield)
            .animation(.easeInOut(duration: 0.25), value: appearanceState.theme)
            .animation(.easeInOut(duration: 0.25), value: appearanceState.accent)
        }
    }

    private var shouldShowShield: Bool {
        screenShieldEnabled && hasOnboarded && scenePhase != .active
    }

    private func registerBackgroundTasks(container: ServiceContainer) {
        // Capture the dependencies we need inside the handler. Container
        // itself is a value type over Sendable members.
        let aiProvider = container.aiProvider
        let entryRepository = container.entryRepository
        let insightRepository = container.insightRepository
        let syncService = container.syncService
        let subscriptionService = container.subscriptionService
        BackgroundTaskService().registerReflectionHandler { task in
            let work = Task {
                // Skip silently if AI is turned off. Otherwise pick the
                // hosted Pro provider when the user has a Pro entitlement
                // (so Anthropic does the work, throttled by the worker's
                // weeklyReflectionAuto policy), or fall through to the
                // existing on-device AIService primary for free users.
                let aiSettings = AISettingsStore().load()
                guard aiSettings.provider != .off else {
                    task.setTaskCompleted(success: true)
                    let frequency = ReflectionSettingsStore().load().frequency
                    try? BackgroundTaskService().scheduleReflection(for: frequency)
                    return
                }
                let provider = await AIProviderFactory.provider(
                    for: .weeklyReflectionAuto,
                    fallback: aiProvider,
                    subscriptionService: subscriptionService
                )
                do {
                    if let insight = try await ReflectionService().generate(
                        aiProvider: provider,
                        entryRepository: entryRepository,
                        insightRepository: insightRepository
                    ) {
                        await NotificationService().postReflectionReady(insightID: insight.id)
                    }
                    task.setTaskCompleted(success: true)
                } catch {
                    task.setTaskCompleted(success: false)
                }
                let frequency = ReflectionSettingsStore().load().frequency
                try? BackgroundTaskService().scheduleReflection(for: frequency)
            }
            task.expirationHandler = { work.cancel() }
        }
        BackgroundTaskService().registerSyncRefreshHandler { task in
            let work = Task {
                await syncService.sync()
                task.setTaskCompleted(success: true)
                // Chain the next refresh so the pipeline keeps catching
                // up even when silent pushes are suppressed.
                try? BackgroundTaskService().scheduleSyncRefresh()
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    /// Hand the push service to the `UIApplicationDelegate` so it can
    /// forward the APNs token, then seed default remote-config values so
    /// reads return sensible results before the first fetch completes.
    private func bootstrapTelemetry() {
        appDelegate.configure(
            pushService: container.pushNotificationService,
            syncService: container.syncService
        )
        seedAnalyticsUserProperties()
        let remoteConfig = container.remoteConfigService
        let legalLinks = container.legalLinks
        Task.detached {
            await remoteConfig.setDefaults(LegalLinks.remoteConfigDefaults)
            _ = try? await remoteConfig.fetchAndActivate()
            await legalLinks.refresh(from: remoteConfig)
        }
        // Kick APNs registration so iOS hands the device token to
        // `AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken`,
        // where it's logged and forwarded to Firebase. The first FCM
        // token is logged from `tokenRefreshes()` below, which fires
        // both on initial issuance and on every subsequent rotation
        // (restore, reinstall, data reset).
        let pushService = container.pushNotificationService
        Task { await pushService.registerForRemoteNotifications() }
        Task {
            for await token in pushService.tokenRefreshes() {
                MiraLog.logger(.general).info("FCM token refreshed: \(token, privacy: .public)")
            }
        }
    }

    /// Snapshots the user-facing settings that gate or shape behavior into
    /// Firebase user properties. Re-set on every cold launch so the cohort
    /// view reflects whatever the user did last session — settings screens
    /// also re-set their own slice when the user flips a toggle.
    private func seedAnalyticsUserProperties() {
        let analytics = container.analyticsService
        let aiSettings = AISettingsStore().load()
        analytics.setUserProperty(
            String(describing: aiSettings.provider),
            forName: "ai_provider"
        )
        analytics.setUserProperty(
            String(describing: aiSettings.remote.provider),
            forName: "remote_ai_provider"
        )
        analytics.setUserProperty(
            LocalModelManager.shared.currentModelID,
            forName: "local_model_id"
        )
        analytics.setUserProperty(
            SyncSettingsStore().load().isEnabled ? "on" : "off",
            forName: "sync_enabled"
        )
        analytics.setUserProperty(
            String(describing: BiometricSettingsStore().load().mode),
            forName: "biometric_mode"
        )
        analytics.setUserProperty(
            String(describing: ReflectionSettingsStore().load().frequency),
            forName: "reflection_frequency"
        )
        analytics.setUserProperty(
            ScreenShieldSettingsStore().load().isEnabled ? "on" : "off",
            forName: "screen_shield_enabled"
        )
    }

    private func bootstrapNotifications() async {
        // Do not request notification authorization here — the onboarding
        // flow asks for it contextually when the user taps the permission
        // card. Scheduling the reflection BGTask is independent of
        // notification auth: if permission is denied, the post is silently
        // dropped, and the schedule is fine to keep in place.
        let frequency = ReflectionSettingsStore().load().frequency
        try? BackgroundTaskService().scheduleReflection(for: frequency)
    }

    /// Refreshes the rolling evening-reminder window and the inactivity
    /// nudge. Re-run on every scene activation so timezone changes,
    /// freshly added entries, and Remote Config overrides take effect
    /// without waiting for the next launch.
    private func bootstrapLocalNotifications() async {
        let prefs = NotificationPreferencesStore().load()
        let catalog = NotificationCopyCatalog(remoteConfig: container.remoteConfigService)
        let service = NotificationService()

        if prefs.evening.isEnabled {
            await service.scheduleEveningRolling(
                time: DateComponents(hour: prefs.evening.hour, minute: prefs.evening.minute),
                copy: catalog
            )
        } else {
            await service.cancelEveningRolling()
        }

        if prefs.inactivity.isEnabled {
            let lastEntry = await fetchLastEntryDate()
            await service.scheduleInactivity(
                lastEntry: lastEntry,
                thresholdDays: prefs.inactivity.thresholdDays,
                time: DateComponents(hour: prefs.inactivity.hour, minute: prefs.inactivity.minute),
                copy: catalog
            )
        } else {
            await service.cancelInactivity()
        }
    }

    private func fetchLastEntryDate() async -> Date? {
        var query = EntryQuery.all
        query.limit = 1
        let snapshots = try? await container.entryRepository.fetch(matching: query)
        return snapshots?.first?.createdAt
    }

    private func bootstrapRemoteKey() async {
        let settings = AISettingsStore().load()
        guard settings.provider == .remote else { return }
        let key = (try? await AIKeychain().apiKey(for: settings.remote.provider)) ?? ""
        await container.aiService.reloadProviders(settings: settings, apiKey: key)
    }

    /// If the user already has iCloud sync switched on (from a previous
    /// launch), start the pusher's change-stream observer and run an
    /// initial push+pull. When it's off, the sync service stays inert
    /// until SyncSettingsView flips the toggle.
    private func bootstrapSync() async {
        guard SyncSettingsStore().load().isEnabled else {
            BackgroundTaskService().cancelSyncRefresh()
            return
        }
        await container.syncService.setEnabled(true)
        try? BackgroundTaskService().scheduleSyncRefresh()
    }

    /// Mirrors the user's Pro entitlement to App-Group UserDefaults so
    /// the widget extension can decide what to render without going
    /// through StoreKit. Reloads widget timelines on every change so
    /// transitions (purchase, restore, lapse) propagate immediately.
    private func syncProEntitlementToWidgets() async {
        let store = WidgetEntitlementsStore()
        let initial = await container.subscriptionService.status
        store.setIsPro(initial.isPro)
        WidgetCenter.shared.reloadAllTimelines()
        for await snapshot in container.subscriptionService.statusUpdates {
            store.setIsPro(snapshot.isPro)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Backfills embeddings for entries that predate the indexing feature
    /// or that were saved before the provider could embed them. Silent on
    /// failure — search just misses older entries until next launch.
    private func backfillEmbeddings() async {
        let service = EmbeddingIndexingService()
        let stream = service.backfill(
            using: container.embeddingProvider,
            repository: container.entryRepository
        )
        do {
            for try await _ in stream {}
        } catch {}
    }
}
