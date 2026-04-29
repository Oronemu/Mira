import Foundation
import SwiftUI

/// Reads the style of the text that would be affected by the current
/// selection. Powers the `TextStyleSheet`'s initial state + the "live
/// preview" pane.
///
/// * For an insertion point, we sample the character immediately before
///   the cursor (or after, if at the start). That character's attributes
///   are what subsequent typing will inherit.
/// * For a range, we return attributes that are **uniform** across the
///   range. If an attribute varies within the selection, it comes back as
///   nil in the resolved style — the UI shows "Mixed" for that facet.
///
/// The returned `EntrySelectionStyle` is deliberately distinct from
/// `EntryTextStyle`: its fields are optional so "mixed / unknown" is a
/// first-class state.
public struct EntrySelectionStyle: Sendable, Hashable {
    public var family: EntryFontFamily?
    public var size: EntryFontSize?
    public var color: EntryTextColor?
    public var bold: Bool?
    public var italic: Bool?
    public var underline: Bool?

    public init(
        family: EntryFontFamily? = nil,
        size: EntryFontSize? = nil,
        color: EntryTextColor? = nil,
        bold: Bool? = nil,
        italic: Bool? = nil,
        underline: Bool? = nil
    ) {
        self.family = family
        self.size = size
        self.color = color
        self.bold = bold
        self.italic = italic
        self.underline = underline
    }
}

public enum EntrySelectionStyleReader {
    /// Resolves the effective style for the given selection. Selection may
    /// be nil when the editor hasn't reported a cursor yet — in that case
    /// we fall back to the attributes at the start of the document (or the
    /// app default if the document is empty).
    public static func currentStyle(
        in content: AttributedString,
        selection: AttributedTextSelection?
    ) -> EntrySelectionStyle {
        guard content.startIndex < content.endIndex else {
            return EntrySelectionStyle()
        }

        let ranges = sampleRanges(for: selection, in: content)
        guard !ranges.isEmpty else {
            return EntrySelectionStyle()
        }

        var family: EntryFontFamily??
        var size: EntryFontSize??
        var color: EntryTextColor??
        var bold: Bool??
        var italic: Bool??
        var underline: Bool??

        func reduce<T: Equatable>(
            _ accumulator: inout T??,
            _ next: T?
        ) {
            switch accumulator {
            case .none:
                accumulator = .some(next)
            case .some(let existing):
                if existing != next { accumulator = .some(nil) }
            }
        }

        for range in ranges {
            for run in content[range].runs {
                reduce(&family, run[EntryFontFamilyAttribute.self])
                reduce(&size, run[EntryFontSizeAttribute.self])
                reduce(&color, run[EntryTextColorAttribute.self])
                reduce(&bold, run[EntryBoldAttribute.self])
                reduce(&italic, run[EntryItalicAttribute.self])
                reduce(&underline, run[EntryUnderlineAttribute.self])
            }
        }

        return EntrySelectionStyle(
            family: family ?? nil,
            size: size ?? nil,
            color: color ?? nil,
            bold: bold ?? nil,
            italic: italic ?? nil,
            underline: underline ?? nil
        )
    }

    // MARK: - Private

    /// Picks the ranges to inspect. For an insertion point we sample one
    /// character to the left (or right if at the start) so we reflect the
    /// attributes typing will inherit. For a range we inspect it directly.
    private static func sampleRanges(
        for selection: AttributedTextSelection?,
        in content: AttributedString
    ) -> [Range<AttributedString.Index>] {
        guard let selection else {
            let start = content.startIndex
            let next = content.index(afterCharacter: start)
            return [start..<next]
        }
        switch selection.indices(in: content) {
        case .insertionPoint(let idx):
            if idx > content.startIndex {
                let prev = content.index(beforeCharacter: idx)
                return [prev..<idx]
            }
            if idx < content.endIndex {
                let next = content.index(afterCharacter: idx)
                return [idx..<next]
            }
            return []
        case .ranges(let ranges):
            let concrete = ranges.ranges
            return concrete.isEmpty ? [] : Array(concrete)
        }
    }
}

private extension AttributedString {
    func index(beforeCharacter idx: AttributedString.Index) -> AttributedString.Index {
        characters.index(before: idx)
    }
    func index(afterCharacter idx: AttributedString.Index) -> AttributedString.Index {
        characters.index(after: idx)
    }
}
