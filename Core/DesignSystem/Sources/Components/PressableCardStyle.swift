import SwiftUI

/// Button style that springs a subtle scale-down while pressed. Use in place
/// of ad-hoc `simultaneousGesture(DragGesture(minimumDistance: 0))` which
/// swallows ScrollView's drag/tap disambiguation and breaks both scroll and
/// tap inside lists.
public struct PressableCardStyle: ButtonStyle {
    public var scale: CGFloat
    public var duration: Double
    public var bounce: Double

    public init(scale: CGFloat = 0.985, duration: Double = 0.3, bounce: Double = 0.2) {
        self.scale = scale
        self.duration = duration
        self.bounce = bounce
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(duration: duration, bounce: bounce), value: configuration.isPressed)
    }
}
