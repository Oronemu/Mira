import Foundation
import UIKit

public enum HapticEvent: Sendable {
    case success
    case warning
    case error
    case selection
    case softImpact
}

/// Thin wrapper around UIFeedbackGenerator so feature code can fire
/// haptics without touching UIKit directly.
public struct HapticsService: Sendable {
    public init() {}

    @MainActor
    public func play(_ event: HapticEvent) {
        switch event {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        case .softImpact:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred()
        }
    }
}
