import Foundation
import CoreKit

/// Compile-time configuration for the Mira-hosted AI proxy. Production
/// URL is the Cloudflare Worker `mira-backend` deployment; debug builds
/// can override to a local `wrangler dev` instance via the env var
/// `MIRA_BACKEND_URL` set on the scheme.
public enum MiraBackend {
    public static var defaultConfig: HostedAIProvider.Config {
        let url: URL = {
            if let override = ProcessInfo.processInfo.environment["MIRA_BACKEND_URL"],
               let parsed = URL(string: override) {
                return parsed
            }
            return URL(string: "https://mira-backend.miradiary.workers.dev")!
        }()
        return HostedAIProvider.Config(baseURL: url)
    }
}
