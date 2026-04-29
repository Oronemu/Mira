import Foundation
import SwiftData

/// Single source of truth for `ModelContainer` construction. Both the live
/// app and tests go through here so the schema list stays consistent.
public enum ModelContainerFactory {
    public static let schema = Schema([
        Entry.self,
        PhotoAsset.self,
        Insight.self,
        AskMiraTurn.self,
        AskMiraChat.self,
    ])

    /// Persistent on-disk container. When `appGroup` is supplied, the SQLite
    /// file lives in the shared App Group container so the widget extension
    /// can read it; otherwise it falls back to the app's Documents directory.
    ///
    /// `cloudKitDatabase: .none` is required: the app has a CloudKit
    /// entitlement for our own encrypted sync pipeline (`CloudKitPusher` /
    /// `CloudKitPuller`), and without this flag SwiftData would
    /// auto-enable `NSPersistentCloudKitContainer` and try to sync the
    /// raw `@Model` rows — which (a) fails at load because our schema
    /// uses non-optional fields and unique constraints that CloudKit
    /// doesn't allow, and (b) would defeat the end-to-end encryption we
    /// promised by shipping plaintext to Apple's servers.
    @MainActor
    public static func live(appGroup: String? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let url = sharedStoreURL(forAppGroup: appGroup) {
            configuration = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Ephemeral container for tests / previews.
    @MainActor
    public static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private static func sharedStoreURL(forAppGroup appGroup: String?) -> URL? {
        guard
            let appGroup,
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        else {
            return nil
        }
        return container.appendingPathComponent("Mira.sqlite")
    }
}
