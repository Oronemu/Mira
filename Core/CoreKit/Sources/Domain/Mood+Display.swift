import Foundation

public extension Mood {
    /// Single-glyph emoji representation. Lives in CoreKit because it is
    /// pure data (no SwiftUI) and is shared by list rows, the editor's
    /// mood picker, and analytics labels.
    var emoji: String {
        switch self {
        case .veryLow: "😢"
        case .low: "😟"
        case .neutral: "😐"
        case .good: "🙂"
        case .veryGood: "😄"
        }
    }

    /// Localised label suitable for accessibility / settings.
    var label: String {
        switch self {
        case .veryLow: String(localized: "Very low")
        case .low: String(localized: "Low")
        case .neutral: String(localized: "Neutral")
        case .good: String(localized: "Good")
        case .veryGood: String(localized: "Very good")
        }
    }
}
