import SwiftUI

/// Large, dreamy, mood-driven background. Takes a collection of raw mood
/// levels (typically from currently visible entries) and layers soft radial
/// blobs in the matching colors. Animates smoothly when the input changes —
/// intended to be driven by scroll position.
public struct AmbientBackground: View {
    private let moodLevels: [Int]
    private let intensity: Double

    public init(moodLevels: [Int], intensity: Double = 1.0) {
        self.moodLevels = moodLevels
        self.intensity = intensity
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                MiraPalette.surface

                ForEach(Array(palette.enumerated()), id: \.offset) { idx, color in
                    RadialGradient(
                        colors: [
                            color.opacity(0.32 * intensity),
                            color.opacity(0.0),
                        ],
                        center: anchor(for: idx),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.75
                    )
                }
            }
            .animation(.spring(duration: 1.4, bounce: 0), value: moodLevels)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Unique mood levels present, sorted for stable ordering. When the user
    /// has no entries yet we fall back to the neutral blob so the screen isn't
    /// flat.
    private var palette: [Color] {
        let unique = Array(Set(moodLevels)).sorted()
        let source = unique.isEmpty ? [3] : unique
        return source.prefix(4).map { MiraPalette.mood(level: $0) }
    }

    private func anchor(for index: Int) -> UnitPoint {
        let anchors: [UnitPoint] = [
            UnitPoint(x: 0.15, y: 0.05),
            UnitPoint(x: 0.90, y: 0.25),
            UnitPoint(x: 0.10, y: 0.70),
            UnitPoint(x: 0.85, y: 0.95),
        ]
        return anchors[index % anchors.count]
    }
}

#Preview("Mixed moods") {
    AmbientBackground(moodLevels: [1, 3, 4, 5])
}

#Preview("Low only") {
    AmbientBackground(moodLevels: [1, 2])
}

#Preview("Empty") {
    AmbientBackground(moodLevels: [])
}
