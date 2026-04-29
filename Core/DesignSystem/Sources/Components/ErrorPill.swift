import SwiftUI

/// Soft coral-tinted pill for surfacing errors or warnings without the harsh
/// red system look. Uses `mood(level: 4)` — the terracotta — so it reads as a
/// warm advisory rather than an alarm.
public struct ErrorPill: View {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(MiraPalette.primaryText.opacity(0.9))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(MiraPalette.mood(level: 4).opacity(0.22))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(MiraPalette.mood(level: 4).opacity(0.35), lineWidth: 1)
                    )
            }
    }
}

#Preview {
    ZStack {
        MiraPalette.surface.ignoresSafeArea()
        VStack(spacing: 16) {
            ErrorPill("Authentication failed.")
            ErrorPill("Something went wrong while saving your entry. Please try again in a moment.")
        }
        .padding()
    }
}
