import SwiftUI
import CoreKit

/// Maps our domain formatting attributes (font family/size, colour,
/// bold/italic/underline) onto the SwiftUI-native attributes that
/// `TextEditor` and `Text` actually render (`.font`, `.foregroundColor`,
/// `.underlineStyle`). Without this mirror, the editor shows plain text
/// regardless of the styles the user applied — SwiftUI only knows
/// foundation attributes, not our `com.mira.*` keys.
///
/// Domain attributes are left untouched so persistence round-trips remain
/// lossless. Mirror attributes are rewritten in full on every call so that
/// toggling a style off (e.g. removing underline) clears the stale mirror
/// it left behind.
public extension AttributedString {
    func resolvedForDisplay() -> AttributedString {
        var output = self
        for run in self.runs {
            let range = run.range
            let family = run[EntryFontFamilyAttribute.self] ?? .serif
            let size = run[EntryFontSizeAttribute.self] ?? .regular
            let bold = run[EntryBoldAttribute.self] ?? false
            let italic = run[EntryItalicAttribute.self] ?? false
            let underline = run[EntryUnderlineAttribute.self] ?? false
            let color = run[EntryTextColorAttribute.self] ?? .preset(.default)

            var font = EntryFontResolver.font(family: family, size: size)
            if bold { font = font.bold() }
            if italic { font = font.italic() }

            output[range].font = font
            output[range].foregroundColor = MiraPalette.textColor(color)
            output[range].underlineStyle = underline ? .single : nil
        }
        return output
    }
}

/// Shared mapping from `(EntryFontFamily, EntryFontSize)` to a concrete
/// SwiftUI `Font`. Used by the display resolver, the renderer, and any
/// preview chrome that needs to match the body style.
public enum EntryFontResolver {
    public static func font(family: EntryFontFamily, size: EntryFontSize) -> Font {
        let points = size.pointSize
        switch family {
        case .serif:       return .system(size: points, weight: .regular, design: .serif)
        case .sans:        return .system(size: points, weight: .regular, design: .default)
        case .rounded:     return .system(size: points, weight: .regular, design: .rounded)
        case .monospaced:  return .system(size: points, weight: .regular, design: .monospaced)
        case .georgia:     return .custom("Georgia", size: points)
        case .avenirNext:  return .custom("AvenirNext-Regular", size: points)
        }
    }
}
