import SwiftUI

/// Reveals a serif inline title (and optional subtitle) in the navigation
/// bar once an in-content hero scrolls past it. Pairs with screens that
/// keep a large `MiraTypography.hero` block at the top of a `ScrollView`.
///
/// Apply on the screen body — the modifier will reach into the nearest
/// enclosing ScrollView via `onScrollGeometryChange`, and the toolbar item
/// merges with any other toolbar content on the screen.
public struct CollapsibleHeroTitleModifier<Inline: View>: ViewModifier {
    private let inline: Inline
    @State private var inlineTitleOpacity: Double = 0

    public init(@ViewBuilder inline: () -> Inline) {
        self.inline = inline()
    }

    public func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Double.self) { geometry in
                let offset = geometry.contentOffset.y
                let start: Double = 20
                let end: Double = 70
                return min(max((offset - start) / (end - start), 0), 1)
            } action: { _, newValue in
                inlineTitleOpacity = newValue
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    inline.opacity(inlineTitleOpacity)
                }
            }
    }
}

/// Default styling for the inline title that appears in the navigation bar:
/// 17pt serif title + optional 11pt uppercase eyebrow subtitle.
public struct CollapsibleHeroInlineTitle: View {
    private let title: Text
    private let subtitle: Text?

    public init(title: Text, subtitle: Text? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 1) {
            title
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
            if let subtitle {
                subtitle
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(MiraPalette.secondaryText)
            }
        }
    }
}

public extension View {
    /// Convenience: title-only inline collapsible header.
    func collapsibleHeroTitle(_ titleKey: LocalizedStringKey) -> some View {
        modifier(CollapsibleHeroTitleModifier {
            CollapsibleHeroInlineTitle(title: Text(titleKey))
        })
    }

    /// Convenience: title + static localized subtitle.
    func collapsibleHeroTitle(_ titleKey: LocalizedStringKey, subtitle subtitleKey: LocalizedStringKey) -> some View {
        modifier(CollapsibleHeroTitleModifier {
            CollapsibleHeroInlineTitle(title: Text(titleKey), subtitle: Text(subtitleKey))
        })
    }

    /// Dynamic-text variant — accepts pre-built `Text` so the caller can
    /// interpolate localized counts / dates.
    func collapsibleHeroTitle(_ title: Text, subtitle: Text? = nil) -> some View {
        modifier(CollapsibleHeroTitleModifier {
            CollapsibleHeroInlineTitle(title: title, subtitle: subtitle)
        })
    }

    /// Fully custom inline view — escape hatch for non-default styling.
    func collapsibleHeroTitle<Inline: View>(@ViewBuilder _ inline: () -> Inline) -> some View {
        modifier(CollapsibleHeroTitleModifier(inline: inline))
    }

    /// Always-visible serif inline title (no collapse). Use for screens whose
    /// in-content hero is branding rather than a page heading (e.g. About,
    /// where the body hero shows the logo + "Mira" but the navbar still needs
    /// the page name).
    func staticHeroTitle(_ titleKey: LocalizedStringKey) -> some View {
        toolbar {
            ToolbarItem(placement: .principal) {
                Text(titleKey)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
            }
        }
    }
}
