import Foundation

/// Snapshot of a Pro user's monthly hosted-AI usage against their caps.
/// Surfaced on the Pro settings screen as "X of Y left this month" so
/// users always know what's available before they hit a soft block.
///
/// Mirrors the wire format of `POST /v1/usage` from the Cloudflare
/// Worker; conversion lives in the `StoreKitSubscriptionService` so this
/// domain type stays JSON-free.
public struct UsageSnapshot: Sendable, Hashable {
    /// Per-intent counters and limit. The worker keys these on
    /// `originalTransactionId` and resets monthly via lazy reload.
    public struct Dimension: Sendable, Hashable {
        public let used: Int
        public let limit: Int
        public let remaining: Int

        public init(used: Int, limit: Int, remaining: Int) {
            self.used = used
            self.limit = limit
            self.remaining = remaining
        }
    }

    /// `YYYY-MM` of the period these counters belong to.
    public let period: String

    /// Last instant of the current period, in UTC. UI renders this as
    /// "Resets on …" using the user's locale; we rely on the server's
    /// time rather than `Date.now` so the displayed reset date matches
    /// when the worker actually rolls counters over.
    public let periodEnd: Date

    /// Hosted Ask Mira requests this period (default cap: 100/mo).
    public let askMira: Dimension

    /// Manually-triggered Weekly Reflection runs this period (default
    /// cap: 2/mo). Auto-fired reflections from the BG task are
    /// unmetered.
    public let manualReflections: Dimension

    public init(
        period: String,
        periodEnd: Date,
        askMira: Dimension,
        manualReflections: Dimension
    ) {
        self.period = period
        self.periodEnd = periodEnd
        self.askMira = askMira
        self.manualReflections = manualReflections
    }
}
