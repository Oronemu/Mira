import Foundation

/// A single Pro-gated capability. Adding a case here is the canonical way to
/// declare a new paywalled surface — feature code consults
/// `SubscriptionService.isEntitled(to:)` rather than reading a status flag,
/// so the gating semantics live in one place.
///
/// Free baseline (never appears here): entry CRUD, calendar, search, sync,
/// biometric lock, Markdown export, Apple Foundation Models, basic widgets,
/// basic stats. See `docs/SUBSCRIPTION_PLAN.md` §2 for the full split.
public enum ProEntitlement: String, Sendable, Hashable, CaseIterable, Codable {
    /// Hosted Claude proxy for Ask Mira and Weekly Reflection. The on-device
    /// Apple Foundation Models path stays free.
    case hostedAI

    /// Tag/mood correlations, year-in-review, mood predictions on top of the
    /// free baseline charts.
    case advancedStats

    /// Custom themes and alternative app icons.
    case themesAndIcons

    /// PDF export with templates. Markdown export remains free.
    case pdfExportTemplates

    /// 1–10 scales, named-emotion picker. The 1–5 default stays free.
    case customMoodScales

    /// Lock Screen widgets and additional Home Screen widget sizes.
    case extraWidgets

    /// User-authored system prompts / personas for Ask Mira.
    case customAIPersonas

    /// Smart filters, collections, folders.
    case smartFilters

    /// Tag-driven goals and habit tracker.
    case goalsAndHabits

    /// Day One / Apple Notes / Markdown importers.
    case importers
}
