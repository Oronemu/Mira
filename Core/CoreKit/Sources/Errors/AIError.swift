import Foundation

public enum AIError: LocalizedError, Sendable {
    case noProviderConfigured
    case providerUnavailable
    case rateLimited
    case invalidAPIKey
    case requestFailed(String)
    case cancelled
    case insufficientMemory(String)
    case downloadIncomplete(completed: Int, total: Int)

    public var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            String(localized: "AI provider not configured.")
        case .providerUnavailable:
            String(localized: "AI provider is not available right now.")
        case .rateLimited:
            String(localized: "AI provider rate limit reached. Try again later.")
        case .invalidAPIKey:
            String(localized: "Couldn't authenticate with the AI provider. If you use your own API key, check it in Settings.")
        case .requestFailed(let message):
            message
        case .cancelled:
            String(localized: "Request cancelled.")
        case .insufficientMemory(let message):
            message
        case .downloadIncomplete(let completed, let total):
            String(format: String(localized: "Download stopped at %1$d of %2$d files. Tap Download again to resume."), completed, total)
        }
    }
}
