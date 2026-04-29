import Foundation

/// No-op fallback for previews, tests, and the default environment.
/// Defaults supplied via `setDefaults` are honoured so a view hierarchy
/// running without the live module still sees sensible static values.
public actor UnimplementedRemoteConfigService: RemoteConfigService {
    private var defaults: [String: RemoteConfigDefaultValue] = [:]

    public init() {}

    public func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) async {
        self.defaults = defaults
    }

    public func fetchAndActivate() async throws -> Bool { false }

    public func string(forKey key: String) async -> String? {
        if case .string(let value) = defaults[key] { return value }
        return nil
    }

    public func bool(forKey key: String) async -> Bool {
        if case .bool(let value) = defaults[key] { return value }
        return false
    }

    public func int(forKey key: String) async -> Int {
        if case .int(let value) = defaults[key] { return value }
        return 0
    }

    public func double(forKey key: String) async -> Double {
        if case .double(let value) = defaults[key] { return value }
        return 0
    }
}
