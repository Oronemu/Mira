import SwiftUI
import DesignSystem

/// Hero icon for the Pro paywall — a quiet constellation of sparkles
/// orbiting a central glyph. Driven by `TimelineView(.animation)` so the
/// motion is continuous without spamming state updates, and tuned to
/// feel ambient rather than attention-seeking (long periods, low scale
/// amplitude, soft opacity floor). The center glyph picks up the warm
/// gold proAccent so the icon reads "premium" without literal coins.
struct PaywallHeroIcon: View {
    /// Six satellites arranged on an ellipse around the center. Each has
    /// its own phase offset so the constellation never feels synced.
    private struct Satellite {
        let angle: Double
        let radiusX: CGFloat
        let radiusY: CGFloat
        let size: CGFloat
        let phase: Double
        let period: Double
    }

    private static let satellites: [Satellite] = [
        Satellite(angle: -0.6, radiusX: 58, radiusY: 42, size: 7, phase: 0.0, period: 4.2),
        Satellite(angle: 0.4, radiusX: 64, radiusY: 38, size: 5, phase: 0.7, period: 3.6),
        Satellite(angle: 1.7, radiusX: 52, radiusY: 46, size: 6, phase: 1.3, period: 4.8),
        Satellite(angle: 2.6, radiusX: 60, radiusY: 40, size: 4, phase: 0.4, period: 3.9),
        Satellite(angle: 3.5, radiusX: 56, radiusY: 44, size: 8, phase: 1.9, period: 5.1),
        Satellite(angle: 4.6, radiusX: 62, radiusY: 38, size: 5, phase: 1.1, period: 4.3),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                // Soft halo behind the glyph — slow breathing.
                let halo = 0.55 + 0.15 * sin(t * 0.6)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                MiraPalette.proAccent(.gold).opacity(0.32),
                                MiraPalette.proAccent(.gold).opacity(0.0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(halo)
                    .blur(radius: 14)

                // Satellites.
                ForEach(0..<Self.satellites.count, id: \.self) { idx in
                    let s = Self.satellites[idx]
                    let pulse = 0.5 + 0.5 * sin((t + s.phase) * (2 * .pi / s.period))
                    Image(systemName: "sparkle")
                        .font(.system(size: s.size, weight: .semibold))
                        .foregroundStyle(MiraPalette.proAccent(.gold))
                        .opacity(0.35 + 0.55 * pulse)
                        .scaleEffect(0.85 + 0.35 * pulse)
                        .offset(
                            x: cos(s.angle) * s.radiusX,
                            y: sin(s.angle) * s.radiusY
                        )
                        .blur(radius: 0.3)
                }

                // Central glyph.
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                MiraPalette.proAccent(.gold),
                                MiraPalette.proAccent(.rose),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .background {
                        Circle()
                            .fill(MiraPalette.surfaceElevated.opacity(0.8))
                    }
                    .glassEffect(.regular, in: Circle())
                    .shadow(color: MiraPalette.proAccent(.gold).opacity(0.35), radius: 18, x: 0, y: 8)
            }
            .frame(width: 180, height: 140)
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    ZStack {
        AmbientBackground(moodLevels: [4, 5], intensity: 0.7)
        PaywallHeroIcon()
    }
}
