import Foundation

/// Discrete mood scale (1...5) used by entries and analytics.
public enum Mood: Int, Sendable, Hashable, CaseIterable, Codable {
    case veryLow = 1
    case low = 2
    case neutral = 3
    case good = 4
    case veryGood = 5
}
