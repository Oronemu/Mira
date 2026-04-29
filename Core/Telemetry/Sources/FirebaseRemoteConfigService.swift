import Foundation
import CoreKit
@preconcurrency import FirebaseRemoteConfig

/// Firebase-backed `RemoteConfigService`. Wraps `FIRRemoteConfig` (thread
/// safe, singleton) in an actor so our own API is naturally serialised.
public actor FirebaseRemoteConfigService: RemoteConfigService {
    private let config: RemoteConfig

    public init(
        minimumFetchInterval: TimeInterval = 3600
    ) {
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = minimumFetchInterval
        config.configSettings = settings
        self.config = config
    }

    public func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) async {
        let bridged = defaults.mapValues(Self.bridge(_:))
        config.setDefaults(bridged)
    }

    @discardableResult
    public func fetchAndActivate() async throws -> Bool {
        let status = try await config.fetchAndActivate()
        return status == .successFetchedFromRemote
    }

    public func string(forKey key: String) async -> String? {
        let value = config.configValue(forKey: key)
        guard value.source != .static else { return nil }
        return value.stringValue.isEmpty ? nil : value.stringValue
    }

    public func bool(forKey key: String) async -> Bool {
        config.configValue(forKey: key).boolValue
    }

    public func int(forKey key: String) async -> Int {
        config.configValue(forKey: key).numberValue.intValue
    }

    public func double(forKey key: String) async -> Double {
        config.configValue(forKey: key).numberValue.doubleValue
    }

    private static func bridge(_ value: RemoteConfigDefaultValue) -> NSObject {
        switch value {
        case .string(let string): return string as NSString
        case .bool(let bool): return NSNumber(value: bool)
        case .int(let int): return NSNumber(value: int)
        case .double(let double): return NSNumber(value: double)
        }
    }
}
