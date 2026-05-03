import Foundation
import CoreKit

/// Picks the right `AIProvider` for a given intent at call time.
///
/// Pro users (those with a verified StoreKit JWS in
/// `SubscriptionService.latestSignedTransaction()`) get a fresh
/// `HostedAIProvider` tagged with the intent so the Cloudflare Worker
/// can route to the right model and apply the right monthly cap. Free
/// users — including Pro users who happen to be offline — fall through
/// to the supplied `fallback`, typically the on-device Apple Foundation
/// provider that `AIService` already manages.
///
/// The factory is intentionally async — it has to ask the subscription
/// service for the current JWS, which on StoreKit 2 walks the
/// `Transaction.currentEntitlements` async sequence. Call once per
/// request from feature state containers.
public enum AIProviderFactory {
    public static func provider(
        for intent: HostedAIProvider.Intent,
        fallback: any AIProvider,
        subscriptionService: any SubscriptionService,
        hostedConfig: HostedAIProvider.Config = MiraBackend.defaultConfig
    ) async -> any AIProvider {
        guard await subscriptionService.latestSignedTransaction() != nil else {
            return fallback
        }
        return HostedAIProvider(
            config: hostedConfig,
            intent: intent,
            subscriptionService: subscriptionService
        )
    }
}
