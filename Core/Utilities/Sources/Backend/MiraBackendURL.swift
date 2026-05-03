import Foundation

/// Resolves the base URL of the Mira Cloudflare Worker (`mira-backend`).
/// Centralised here so both AIKit (hosted AI proxy) and Subscriptions
/// (usage endpoint) hit the same host without one module importing the
/// other. Debug builds can override the URL via the `MIRA_BACKEND_URL`
/// environment variable on the scheme — useful for `wrangler dev`.
public enum MiraBackendURL {
    /// Production deployment. Override with the `MIRA_BACKEND_URL`
    /// scheme env var when pointing at a local worker.
    public static func resolve() -> URL {
        if let override = ProcessInfo.processInfo.environment["MIRA_BACKEND_URL"],
           let parsed = URL(string: override) {
            return parsed
        }
        return URL(string: "https://mira-backend.miradiary.workers.dev")!
    }
}
