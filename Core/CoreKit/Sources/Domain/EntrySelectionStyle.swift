import Foundation

/// Snapshot of the style under the current selection. Drives the Text
/// Style sheet's initial state and the dock's live indicators.
///
/// Each facet is optional so "mixed" (selection spans runs with different
/// values) is a first-class state — the UI renders that as "Mixed" and
/// leaves the picker unselected. Computed by `MiraRichTextController` from
/// the live UITextView's `typingAttributes` (insertion point) or by
/// reducing over the runs in the selected range.
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

