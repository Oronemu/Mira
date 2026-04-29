import Foundation

/// Sendable wrapper around the subset of types Analytics backends accept as
/// event parameters. Keeping this typed (instead of `[String: Any]`) both
/// satisfies Swift 6 strict concurrency and forces callers to think about
/// what they're sending — no accidental logging of arbitrary values.
public enum AnalyticsParameterValue: Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

/// Product-usage analytics. The only data this protocol is allowed to carry
/// are non-content events — screen views, feature counters, enum-like
/// states. Passing entry text, photos, reflections, embeddings, or AI
/// prompts through here is a privacy violation enforced by code review.
public protocol AnalyticsService: Sendable {
    /// Record a named event. `parameters` must contain no user-authored
    /// journal content.
    func log(event: String, parameters: [String: AnalyticsParameterValue])

    /// Attach a persistent, non-content property to the current install
    /// (e.g. `user_theme`, `ai_provider`). Passing `nil` clears it.
    func setUserProperty(_ value: String?, forName name: String)

    /// Master switch for analytics collection — wired to the in-app
    /// "Diagnostics & Analytics" toggle. Setting this to `false` must halt
    /// event delivery at the backend level.
    func setEnabled(_ enabled: Bool)
}

public extension AnalyticsService {
    /// Convenience: log an event with no parameters.
    func log(event: String) {
        log(event: event, parameters: [:])
    }
}
