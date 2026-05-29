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

    /// Lock Screen widgets and additional Home Screen widget sizes.
    case extraWidgets

    /// User-authored system prompts / personas for Ask Mira.
    case customAIPersonas

    /// Saved searches the user can come back to (`SavedFilter`).
    case smartFilters

    /// Tag-driven goals and habit tracker.
    case goalsAndHabits

    /// Day One / Apple Notes / Markdown importers.
    case importers

    /// User-created stickers lifted from photos with on-device background
    /// removal. The bundled drawstyle pack remains free.
    case customStickers

    /// Stable snake_case identifier for analytics. The enum's `rawValue`
    /// is camelCase to match Swift idioms; this version is for event
    /// parameters where the rest of the project uses snake_case
    /// (`insight_generated`, `local_model_selected`, etc.).
    public var analyticsName: String {
        switch self {
        case .hostedAI:           return "hosted_ai"
        case .advancedStats:      return "advanced_stats"
        case .themesAndIcons:     return "themes_and_icons"
        case .pdfExportTemplates: return "pdf_export_templates"
        case .extraWidgets:       return "extra_widgets"
        case .customAIPersonas:   return "custom_ai_personas"
        case .smartFilters:       return "smart_filters"
        case .goalsAndHabits:     return "goals_and_habits"
        case .importers:          return "importers"
        case .customStickers:     return "custom_stickers"
        }
    }
}
