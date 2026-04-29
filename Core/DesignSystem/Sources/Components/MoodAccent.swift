import SwiftUI

/// Thin vertical mood-colored strip used on the leading edge of entry cards.
/// Accepts a raw mood level (1…5) so DesignSystem stays domain-free.
public struct MoodAccent: View {
    private let level: Int?
    private let width: CGFloat
    private let cornerRadius: CGFloat

    public init(level: Int?, width: CGFloat = 4, cornerRadius: CGFloat = 2) {
        self.level = level
        self.width = width
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0.95),
                        color.opacity(0.55),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width)
    }

    private var color: Color {
        level.map { MiraPalette.mood(level: $0) } ?? MiraPalette.moodUnknown
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(1...5, id: \.self) { level in
            MoodAccent(level: level)
                .frame(height: 60)
        }
        MoodAccent(level: nil)
            .frame(height: 60)
    }
    .padding()
}
