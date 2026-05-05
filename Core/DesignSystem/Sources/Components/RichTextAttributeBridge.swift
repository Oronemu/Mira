import UIKit
import SwiftUI
import CoreKit

/// Bidirectional mapping between Mira's domain `AttributedString` (custom
/// `EntryFontFamilyAttribute` etc.) and `NSAttributedString` for UIKit.
///
/// UIKit collapses bold/italic into UIFont traits and erases anything it
/// doesn't know about. To round-trip lossless, we mirror the discrete
/// domain values — family, size, color — into shadow `NSAttributedString.Key`
/// keys so we can recover them on the way back. Bold/italic/underline are
/// derived from the UIFont traits + underline style, since those *are*
/// what UIKit edits when the system Format menu fires `toggleBoldface:` /
/// `toggleItalics:` / `toggleUnderline:` actions.
public enum RichTextAttributeBridge {

    // MARK: - Shadow keys

    public static let familyKey = NSAttributedString.Key("com.mira.fontFamily")
    public static let sizeKey = NSAttributedString.Key("com.mira.fontSize")
    public static let colorKey = NSAttributedString.Key("com.mira.textColor")

    /// All shadow keys + the foundation keys we set, used by the editor when
    /// resetting typing attributes / clearing storage.
    public static let allManagedKeys: [NSAttributedString.Key] = [
        .font,
        .foregroundColor,
        .underlineStyle,
        familyKey,
        sizeKey,
        colorKey,
    ]

    // MARK: - Defaults

    public static func defaultAttributes() -> [NSAttributedString.Key: Any] {
        attributes(
            family: .serif,
            size: .regular,
            color: .preset(.default),
            bold: false,
            italic: false,
            underline: false
        )
    }

    /// Builds a UIKit attribute dict for the given resolved style. Used by
    /// the editor to seed `typingAttributes` and to apply style edits to a
    /// selection.
    public static func attributes(
        family: EntryFontFamily,
        size: EntryFontSize,
        color: EntryTextColor,
        bold: Bool,
        italic: Bool,
        underline: Bool
    ) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [
            .font: uiFont(family: family, size: size, bold: bold, italic: italic),
            .foregroundColor: uiColor(for: color),
            familyKey: family.rawValue,
            sizeKey: size.rawValue,
            colorKey: color.storageString,
        ]
        if underline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attrs
    }

    // MARK: - AttributedString → NSAttributedString

    /// Converts a domain `AttributedString` into an `NSAttributedString` ready
    /// for `UITextView.attributedText`. Empty input yields an empty result.
    public static func nsAttributedString(from content: AttributedString) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for run in content.runs {
            let slice = String(content[run.range].characters)
            guard !slice.isEmpty else { continue }
            let family = run[EntryFontFamilyAttribute.self] ?? .serif
            let size = run[EntryFontSizeAttribute.self] ?? .regular
            let color = run[EntryTextColorAttribute.self] ?? .preset(.default)
            let bold = run[EntryBoldAttribute.self] ?? false
            let italic = run[EntryItalicAttribute.self] ?? false
            let underline = run[EntryUnderlineAttribute.self] ?? false
            let attrs = attributes(
                family: family,
                size: size,
                color: color,
                bold: bold,
                italic: italic,
                underline: underline
            )
            output.append(NSAttributedString(string: slice, attributes: attrs))
        }
        return output
    }

    // MARK: - NSAttributedString → AttributedString

    /// Converts an `NSAttributedString` (from `UITextView.attributedText`)
    /// back into a domain `AttributedString`. Shadow keys are trusted when
    /// present; otherwise values are derived from foundation attrs (bold/
    /// italic from UIFont traits, underline from `.underlineStyle`).
    public static func attributedString(from ns: NSAttributedString) -> AttributedString {
        guard ns.length > 0 else { return AttributedString() }
        var output = AttributedString()
        ns.enumerateAttributes(in: NSRange(location: 0, length: ns.length)) { attrs, range, _ in
            let slice = (ns.string as NSString).substring(with: range)
            var piece = AttributedString(slice)
            let pieceRange = piece.startIndex..<piece.endIndex
            guard pieceRange.lowerBound < pieceRange.upperBound else { return }

            // Family
            if let raw = attrs[familyKey] as? String,
               let family = EntryFontFamily(rawValue: raw) {
                piece[pieceRange][EntryFontFamilyAttribute.self] = family
            }
            // Size
            if let raw = attrs[sizeKey] as? Int,
               let size = EntryFontSize(rawValue: raw) {
                piece[pieceRange][EntryFontSizeAttribute.self] = size
            }
            // Color (shadow-only; UIColor inspection would lose preset identity)
            if let raw = attrs[colorKey] as? String,
               let color = EntryTextColor(storageString: raw) {
                piece[pieceRange][EntryTextColorAttribute.self] = color
            }
            // Bold / italic — read from the resolved UIFont traits so the
            // system Format menu's toggle is reflected in the domain.
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) {
                    piece[pieceRange][EntryBoldAttribute.self] = true
                }
                if traits.contains(.traitItalic) {
                    piece[pieceRange][EntryItalicAttribute.self] = true
                }
            }
            // Underline
            if let raw = attrs[.underlineStyle] as? Int, raw != 0 {
                piece[pieceRange][EntryUnderlineAttribute.self] = true
            }

            output.append(piece)
        }
        return output
    }

    // MARK: - UIFont / UIColor resolvers

    public static func uiFont(
        family: EntryFontFamily,
        size: EntryFontSize,
        bold: Bool,
        italic: Bool
    ) -> UIFont {
        let points = size.pointSize
        let base: UIFont
        switch family {
        case .serif:
            base = systemFont(points: points, design: .serif)
        case .sans:
            base = systemFont(points: points, design: .default)
        case .rounded:
            base = systemFont(points: points, design: .rounded)
        case .monospaced:
            base = systemFont(points: points, design: .monospaced)
        case .georgia:
            base = UIFont(name: "Georgia", size: points)
                ?? systemFont(points: points, design: .serif)
        case .avenirNext:
            base = UIFont(name: "AvenirNext-Regular", size: points)
                ?? systemFont(points: points, design: .default)
        }
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        if traits.isEmpty { return base }
        let descriptor = base.fontDescriptor.withSymbolicTraits(
            base.fontDescriptor.symbolicTraits.union(traits)
        ) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: points)
    }

    private static func systemFont(
        points: CGFloat,
        design: UIFontDescriptor.SystemDesign
    ) -> UIFont {
        let base = UIFont.systemFont(ofSize: points)
        let descriptor = base.fontDescriptor.withDesign(design) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: points)
    }

    public static func uiColor(for color: EntryTextColor) -> UIColor {
        // Resolve via the shared palette so light/dark adapts correctly.
        UIColor(MiraPalette.textColor(color))
    }
}
