import Foundation
import CoreKit
import Persistence
import Utilities
import AIKit
import Subscriptions
import Telemetry

/// Composition root. Holds every long-lived service / repository the app uses.
/// `live()` wires production implementations; tests / previews call the
/// memberwise initializer with mocks.
struct ServiceContainer {
    let entryRepository: any EntryRepository
    let insightRepository: any InsightRepository
    let askMiraRepository: any AskMiraRepository
    let aiService: AIService
    let embeddingProvider: any EmbeddingProvider
    let photoStoring: any PhotoStoring
    let customStickerStore: any CustomStickerStoring
    let analyticsService: any AnalyticsService
    let crashReporter: any CrashReporter
    let pushNotificationService: any PushNotificationService
    let remoteConfigService: any RemoteConfigService
    let legalLinks: LegalLinks
    let modelDownloadCoordinator: ModelDownloadCoordinator
    let syncService: SyncService
    let subscriptionService: any SubscriptionService

    var aiProvider: any AIProvider { aiService }

    static let cloudKitContainerIdentifier = "iCloud.com.veilbytesoft.Mira"

    @MainActor
    static func live() -> ServiceContainer {
        do {
            let modelContainer = try ModelContainerFactory.live(appGroup: AppGroup.identifier)
            let aiSettings = AISettingsStore().load()
            let aiService = AIService(settings: aiSettings)
            // When a model finishes downloading we want the active AI
            // provider to notice — otherwise the UI shows "ready" but the
            // MLX provider still thinks there's nothing to load.
            let coordinator = ModelDownloadCoordinator(
                didFinishDownload: { [aiService] _, success in
                    guard success else { return }
                    let settings = AISettingsStore().load()
                    let key = (try? await AIKeychain().apiKey(for: settings.remote.provider)) ?? ""
                    await aiService.reloadProviders(settings: settings, apiKey: key)
                }
            )
            let entryRepository = SwiftDataEntryRepository(modelContainer: modelContainer)
            let insightRepository = SwiftDataInsightRepository(modelContainer: modelContainer)
            let photoStoring: any PhotoStoring = try PhotoStorageService()
            let customStickerStore: any CustomStickerStoring = try CustomStickerStorageService()
            let syncService = try makeSyncService(
                entryRepository: entryRepository,
                insightRepository: insightRepository,
                photoStoring: photoStoring,
                customStickerStore: customStickerStore
            )
            return ServiceContainer(
                entryRepository: entryRepository,
                insightRepository: insightRepository,
                askMiraRepository: SwiftDataAskMiraRepository(modelContainer: modelContainer),
                aiService: aiService,
                embeddingProvider: NLEmbeddingProvider() ?? UnimplementedEmbeddingProvider(),
                photoStoring: photoStoring,
                customStickerStore: customStickerStore,
                analyticsService: FirebaseAnalyticsService(),
                crashReporter: FirebaseCrashReporter(),
                pushNotificationService: FirebasePushNotificationService(),
                remoteConfigService: FirebaseRemoteConfigService(),
                legalLinks: LegalLinks(),
                modelDownloadCoordinator: coordinator,
                syncService: syncService,
                subscriptionService: makeSubscriptionService()
            )
        } catch {
            // Persistent stores must succeed for the app to be usable.
            fatalError("Failed to bootstrap ServiceContainer: \(error)")
        }
    }

    /// Constructs the live subscription service and primes it with the
    /// user's current entitlement + the Transaction.updates listener.
    /// Returning the actor synchronously keeps `live()` non-async; the
    /// async bootstrap runs in a detached Task.
    private static func makeSubscriptionService() -> StoreKitSubscriptionService {
        let service = StoreKitSubscriptionService()
        Task { await service.bootstrap() }
        return service
    }

    /// Builds the sync stack: CloudKit database adapter, encrypted
    /// codec, durable pending-push queue + change-token store (both
    /// anchored in the App Group container so they're reachable from
    /// any process that might want them later), pusher + puller, and
    /// the `SyncService` façade that wires them together.
    private static func makeSyncService(
        entryRepository: any EntryRepository,
        insightRepository: any InsightRepository,
        photoStoring: any PhotoStoring,
        customStickerStore: any CustomStickerStoring
    ) throws -> SyncService {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier
        ) else {
            // If the app group container is missing we'd rather run
            // without sync than crash the app — this path is hit in
            // the simulator before entitlements are wired.
            return SyncService()
        }
        let syncDir = groupURL.appendingPathComponent("Sync", isDirectory: true)
        let encryption = SyncEncryption()
        let codec = SyncPayloadCodec(encryption: encryption)
        let queue = try PendingPushQueue(url: syncDir.appendingPathComponent("pending-push.json"))
        let tokens = try ChangeTokenStore(url: syncDir.appendingPathComponent("change-token.bin"))
        let database = CKDatabaseAdapter(containerIdentifier: cloudKitContainerIdentifier)
        let pusher = CloudKitPusher(
            database: database,
            codec: codec,
            queue: queue,
            entries: entryRepository,
            insights: insightRepository,
            photos: photoStoring,
            customStickers: customStickerStore
        )
        let puller = CloudKitPuller(
            database: database,
            codec: codec,
            tokens: tokens,
            entries: entryRepository,
            insights: insightRepository,
            photos: photoStoring,
            customStickers: customStickerStore
        )
        return SyncService(
            encryption: encryption,
            components: .init(
                database: database,
                pusher: pusher,
                puller: puller,
                queue: queue,
                tokens: tokens
            )
        )
    }
}
