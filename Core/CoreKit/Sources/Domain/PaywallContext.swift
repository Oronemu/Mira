import Foundation

/// Where the paywall was triggered from. Drives the headline copy ("Unlock
/// Ask Mira" vs "Unlock Themes" vs the generic "Mira Pro") and lets
/// analytics attribute conversions to specific entry points without each
/// feature having to know paywall internals.
public enum PaywallContext: Sendable, Hashable, Identifiable {
    /// Generic upgrade entry point — Settings banner, About screen.
    case general

    /// User tried to use a Pro-gated feature. The carried entitlement lets
    /// the paywall surface a feature-specific headline.
    case feature(ProEntitlement)

    /// Stable id so SwiftUI's `.sheet(item:)` can drive presentation off a
    /// `PaywallContext?` without losing identity when the case payload
    /// changes.
    public var id: String {
        switch self {
        case .general: "general"
        case .feature(let entitlement): "feature.\(entitlement.rawValue)"
        }
    }

    /// snake_case identifier for the `paywall_presented` event's
    /// `context` parameter. Distinct from `id` (which is mixed-case for
    /// SwiftUI identity) so analytics aggregations stay readable.
    public var analyticsName: String {
        switch self {
        case .general: "general"
        case .feature(let entitlement): "feature_\(entitlement.analyticsName)"
        }
    }

    /// Localised hero title shown above the product list.
    public var headline: String {
        switch self {
        case .general:
            String(localized: "Mira Pro")
        case .feature(.hostedAI):
            String(localized: "Unlock Ask Mira and reflections")
        case .feature(.advancedStats):
            String(localized: "See deeper patterns in your journal")
        case .feature(.themesAndIcons):
            String(localized: "Make Mira yours")
        case .feature(.pdfExportTemplates):
            String(localized: "Export beautifully")
        case .feature(.extraWidgets):
            String(localized: "More widgets, everywhere")
        case .feature(.customAIPersonas):
            String(localized: "Make Mira your own")
        case .feature(.smartFilters):
            String(localized: "Save the filters you keep coming back to")
        case .feature(.goalsAndHabits):
            String(localized: "Build habits with your journal")
        case .feature(.importers):
            String(localized: "Bring everything to Mira")
        }
    }

    /// Single-sentence subtitle that explains what the user is unlocking.
    public var subheadline: String {
        switch self {
        case .general:
            String(localized: "Hosted AI, advanced analytics, themes, and more.")
        case .feature(.hostedAI):
            String(localized: "Conversations and weekly reflections, set up in seconds.")
        case .feature(.advancedStats):
            String(localized: "Tag correlations, year-in-review, and mood predictions.")
        case .feature(.themesAndIcons):
            String(localized: "Themes and alternative app icons crafted for journaling.")
        case .feature(.pdfExportTemplates):
            String(localized: "PDF templates with your photos, mood, and tags laid out cleanly.")
        case .feature(.extraWidgets):
            String(localized: "Lock Screen widgets and additional Home Screen sizes.")
        case .feature(.customAIPersonas):
            String(localized: "Author the system prompt that shapes Ask Mira's voice.")
        case .feature(.smartFilters):
            String(localized: "Saved searches that capture the way you read your journal.")
        case .feature(.goalsAndHabits):
            String(localized: "Track tag-driven habits and goals alongside your journal.")
        case .feature(.importers):
            String(localized: "Import from Day One, Apple Notes, and Markdown files.")
        }
    }
}
