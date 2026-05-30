import Foundation
import CoreKit
import Utilities

/// Thin orchestrator over a primary and a fallback `AIProvider`. Tries the
/// primary first, falls through to the fallback on failure or when the
/// primary reports unavailable.
public actor AIService: AIProvider {
    private var primary: any AIProvider
    private var fallback: any AIProvider
    private(set) public var settings: AISettings
    private(set) public var remoteAPIKey: String

    public init(settings: AISettings = .default, apiKey: String = "") {
        self.settings = settings
        self.remoteAPIKey = apiKey
        let providers = Self.providers(for: settings, apiKey: apiKey)
        self.primary = providers.primary
        self.fallback = providers.fallback
    }

    public func reloadProviders(settings: AISettings, apiKey: String? = nil) {
        self.settings = settings
        if let apiKey { self.remoteAPIKey = apiKey }
        let providers = Self.providers(for: settings, apiKey: remoteAPIKey)
        self.primary = providers.primary
        self.fallback = providers.fallback
    }

    public var isAvailable: Bool {
        get async {
            if await primary.isAvailable { return true }
            return await fallback.isAvailable
        }
    }

    /// Strict prompts cost only a few extra tokens, so if either side
    /// of the chain might end up handling the request (and prefers
    /// strict wording), assemble for strict. This errs toward safety
    /// when the runtime fallback to MLX kicks in mid-request.
    public var requiresStrictPrompts: Bool {
        get async {
            if await primary.requiresStrictPrompts { return true }
            return await fallback.requiresStrictPrompts
        }
    }

    public func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        if await primary.isAvailable {
            do {
                let upstream = try await primary.stream(request)
                return await primary.requiresStrictPrompts ? OutputGuard.wrap(upstream) : upstream
            } catch AIError.cancelled {
                throw AIError.cancelled
            } catch {
                // Primary failed — try fallback if it is a different provider.
                guard await fallback.isAvailable else { throw error }
                let upstream = try await fallback.stream(request)
                return await fallback.requiresStrictPrompts ? OutputGuard.wrap(upstream) : upstream
            }
        }
        guard await fallback.isAvailable else { throw AIError.providerUnavailable }
        let upstream = try await fallback.stream(request)
        return await fallback.requiresStrictPrompts ? OutputGuard.wrap(upstream) : upstream
    }

    private static func providers(
        for settings: AISettings,
        apiKey: String
    ) -> (primary: any AIProvider, fallback: any AIProvider) {
        switch settings.provider {
        case .off:
            return (NoAIProvider(), NoAIProvider())
        case .local:
            return (MLXLocalProvider(), NoAIProvider())
        case .remote:
            let credentials = RemoteAIProvider.Credentials(
                config: settings.remote,
                apiKey: apiKey
            )
            // Remote primary falls back to the on-device model when the
            // network request fails and a model is downloaded.
            return (RemoteAIProvider(credentials: credentials), MLXLocalProvider())
        }
    }
}
