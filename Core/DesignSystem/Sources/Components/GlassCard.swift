import SwiftUI

/// iOS 26 Liquid Glass card. Optionally bleeds a soft mood tint under the glass
/// so the card inherits the emotional color of its content without shouting.
public struct GlassCard<Content: View>: View {
    private let tintLevel: Int?
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        tintLevel: Int? = nil,
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.tintLevel = tintLevel
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding)
            .background {
                if let tintLevel {
                    shape.fill(MiraPalette.mood(level: tintLevel).opacity(0.10))
                }
            }
            .glassEffect(.regular, in: shape)
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
    }
}

#Preview {
    ZStack {
        MiraPalette.surface.ignoresSafeArea()
        VStack(spacing: 16) {
            GlassCard(tintLevel: 5) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Apr 12 · Sunday").eyebrowStyle()
                    Text("Long walk through the park — felt lighter than I have in weeks.")
                        .font(MiraTypography.entryBody)
                }
            }
            GlassCard(tintLevel: 1) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Apr 09 · Thursday").eyebrowStyle()
                    Text("Couldn't focus at all today. Draining.")
                        .font(MiraTypography.entryBody)
                }
            }
        }
        .padding()
    }
}
