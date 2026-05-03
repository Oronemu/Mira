import Foundation

/// Visual style applied to PDF exports. Free users always get
/// `.minimal` (the current export). Pro users pick from the full set
/// in the export sheet.
public enum PDFTemplate: String, Sendable, Hashable, CaseIterable, Codable {
    /// Sans-serif, generous whitespace, no decorative elements. The
    /// historical default and the only template free users see.
    case minimal

    /// Serif-led typography with drop-cap accents and rule dividers.
    /// Reads like an essay collection.
    case editorial

    /// Faint paper rules underneath serif body text. Casual feel,
    /// intended for printing.
    case notebook
}
