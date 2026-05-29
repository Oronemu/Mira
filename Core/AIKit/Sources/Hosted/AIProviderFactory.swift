import Foundation
import CoreKit
import Utilities

/// Picks the right `AIProvider` for a given intent at call time.
///
/// Routing rules, in order:
///
/// 1. The user's `AISettings.provider` is the source of truth. If they
///    picked `.off` or `.local` ("On-device — Nothing leaves the
///    phone"), we **must** stay on the local fallback — even for Pro
///    subscribers. Silently routing local-mode requests through the
///    hosted proxy would break the privacy promise *and* burn the
///    user's monthly cap for traffic they never asked to send.
/// 2. For `.remote` ("Cloud") we prefer the hosted Pro proxy when the
///    user has a verified StoreKit JWS, so requests go through Mira's
///    Cloudflare Worker (which applies the per-intent caps and keeps
///    the API key off device).
/// 3. Anything else — Pro check fails, no settings yet — falls through
///    to the supplied `fallback`, typically `AIService` configured
///    against the on-device model.
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
        hostedConfig: HostedAIProvider.Config = MiraBackend.defaultConfig,
        settingsStore: AISettingsStore = AISettingsStore(),
        consentStore: RemoteAIConsentStore = RemoteAIConsentStore()
    ) async -> any AIProvider {
        let settings = settingsStore.load()
        // The user's explicit "On-device" / "Off" choice always wins.
        // Hosted only enters the picture for `.remote`.
        guard settings.provider == .remote else {
            return fallback
        }
        // App Store guideline 5.1.1(i) / 5.1.2(i): no journal context may
        // be sent to Anthropic without an explicit in-app consent. The UI
        // gates Settings → Cloud / Ask Mira / Reflections separately, but
        // we belt-and-suspenders the factory so any code path (including
        // the BGTask weekly-reflection handler) that forgets to ask first
        // falls through to the on-device fallback instead of silently
        // sending data.
        guard consentStore.load().hasGiven else {
            return fallback
        }
        // Pro access can come from a verified StoreKit JWS *or* a custom
        // redeem grant (which has no JWS, only a device-bound id). Both
        // authenticate the hosted proxy — `HostedAIProvider` prefers the
        // JWS and falls back to `redeemUserId` internally — so accept
        // either here. Checking only the JWS silently routed redeem-code
        // Pro users back to the BYOK/on-device fallback, which surfaced a
        // misleading "invalid API key" error.
        let hasJWS = await subscriptionService.latestSignedTransaction() != nil
        let hasRedeem = await subscriptionService.redeemUserID != nil
        guard hasJWS || hasRedeem else {
            return fallback
        }
        return HostedAIProvider(
            config: hostedConfig,
            intent: intent,
            subscriptionService: subscriptionService
        )
    }
}
