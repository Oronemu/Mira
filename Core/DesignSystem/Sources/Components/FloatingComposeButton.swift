import SwiftUI

/// Circular Liquid Glass FAB with a soft mood-colored aura behind it.
/// Designed to sit in a ZStack overlay at the bottom-trailing of a screen.
public struct FloatingComposeButton: View {
    private let moodLevel: Int?
    private let systemImage: String
    private let action: () -> Void

    public init(
        moodLevel: Int? = nil,
        systemImage: String = "pencil.line",
        action: @escaping () -> Void
    ) {
        self.moodLevel = moodLevel
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(auraColor.opacity(0.40))
                .frame(width: 84, height: 84)
                .blur(radius: 22)

            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MiraPalette.primaryText)
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableCardStyle(scale: 0.92, duration: 0.28, bounce: 0.35))
            .glassEffect(.regular.interactive(), in: Circle())
            .sensoryFeedback(.impact(weight: .light), trigger: false)
            .accessibilityLabel("New entry")
        }
    }

    private var auraColor: Color {
        moodLevel.map { MiraPalette.mood(level: $0) } ?? MiraPalette.accent
    }
}

#Preview {
    ZStack {
        MiraPalette.surface.ignoresSafeArea()
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingComposeButton(moodLevel: 4) {}
                    .padding(24)
            }
        }
    }
}
