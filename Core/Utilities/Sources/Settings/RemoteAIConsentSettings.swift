import Foundation

/// Explicit user consent to send journal context to a third-party AI
/// service (Anthropic Claude through Mira's Cloudflare proxy).
///
/// Required by Apple App Store Review guidelines 5.1.1(i) / 5.1.2(i):
/// disclosure and consent in the app's privacy policy alone is not
/// sufficient — the app must present an in-app prompt that identifies
/// the data, the recipient, and asks for permission *before* any
/// Pro-AI request is sent. We persist the decision so we don't keep
/// re-asking on every prompt; the user can revoke at any time by
/// switching the provider away from Cloud in Settings → Intelligence
/// (which clears `hasGiven`).
public struct RemoteAIConsentSettings: Sendable, Hashable, Codable {
    public var hasGiven: Bool
    public var decidedAt: Date?

    public init(hasGiven: Bool = false, decidedAt: Date? = nil) {
        self.hasGiven = hasGiven
        self.decidedAt = decidedAt
    }
}

public extension RemoteAIConsentSettings {
    static let `default` = RemoteAIConsentSettings()
}

public struct RemoteAIConsentStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "remote_ai_consent.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> RemoteAIConsentSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(RemoteAIConsentSettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    public func save(_ settings: RemoteAIConsentSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    public func grant() {
        save(RemoteAIConsentSettings(hasGiven: true, decidedAt: Date()))
    }

    public func revoke() {
        save(RemoteAIConsentSettings(hasGiven: false, decidedAt: Date()))
    }
}
