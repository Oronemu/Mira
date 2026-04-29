import SwiftUI
import CoreKit

public enum MiraTypography {
    // MARK: - Standard

    public static let largeTitle = Font.largeTitle.weight(.semibold)
    public static let title = Font.title.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let callout = Font.callout
    public static let caption = Font.caption.weight(.medium)

    // MARK: - Editorial (Stoic-inspired)

    /// Large serif display — for hero headers ("Journal").
    public static let hero = Font.system(size: 40, weight: .regular, design: .serif)

    /// Serif display — for month/section titles.
    public static let displayTitle = Font.system(size: 28, weight: .semibold, design: .serif)

    /// Small uppercase label used above or alongside content. Pair with
    /// `View.eyebrowStyle()` to get tracking + case transform.
    public static let eyebrow = Font.system(size: 11, weight: .semibold)

    /// Serif body used in entry text — gives the journal an "editorial" feel.
    public static let entryBody = Font.system(.body, design: .serif)

    /// Emphasised serif body — for hoisted snippets in AskMira / Insights.
    public static let entryBodyEmphasized = Font.system(.body, design: .serif).weight(.medium)

    /// Body font resolved against a per-entry `EntryTextStyle`. Size and
    /// family come from the style; weight stays regular so the editorial
    /// feel isn't fighting against user-chosen fonts.
    public static func entryBody(style: EntryTextStyle) -> Font {
        let size = style.size.pointSize
        switch style.family {
        case .serif:
            return .system(size: size, weight: .regular, design: .serif)
        case .sans:
            return .system(size: size, weight: .regular, design: .default)
        case .rounded:
            return .system(size: size, weight: .regular, design: .rounded)
        case .monospaced:
            return .system(size: size, weight: .regular, design: .monospaced)
        case .georgia:
            return .custom("Georgia", size: size)
        case .avenirNext:
            return .custom("AvenirNext-Regular", size: size)
        }
    }
}

public extension View {
    /// Applies the canonical "eyebrow" styling — small, tracked, uppercase.
    /// Use on `Text` above section headers, dates, or metadata rows.
    func eyebrowStyle(color: Color = MiraPalette.secondaryText) -> some View {
        self.font(MiraTypography.eyebrow)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
