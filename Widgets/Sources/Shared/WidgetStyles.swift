import SwiftUI
import WidgetKit
import DesignSystem

/// Horizontal 7-cell mood sparkline used by both home widget sizes. Each
/// cell is a small rounded rectangle colored by mood; missing days render
/// as a muted placeholder. In accented rendering mode (Lock Screen / tinted
/// StandBy) the cells fall back to opacity-differentiated tints since the
/// system flattens colors.
struct MoodSparkline: View {
    let values: [Int?]
    var height: CGFloat = 10
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color(for: level))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
    }

    private func color(for level: Int?) -> Color {
        if renderingMode == .accented || renderingMode == .vibrant {
            guard let level else { return .white.opacity(0.15) }
            // Normalised 1→5 to 0.25→0.95 opacity so the system's tint still
            // reads as a gradient on the Lock Screen.
            return .white.opacity(0.25 + Double(level - 1) * 0.175)
        }
        guard let level else {
            return MiraPalette.primaryText.opacity(0.08)
        }
        return MiraPalette.mood(level: level)
    }
}

/// Soft mood-tinted background used as the widget's containerBackground.
/// Falls back to the neutral surface when no mood is available.
struct WidgetMoodBackground: View {
    let moodLevel: Int?
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack {
            MiraPalette.surface
            if renderingMode == .fullColor, let moodLevel {
                LinearGradient(
                    colors: [
                        MiraPalette.mood(level: moodLevel).opacity(0.26),
                        MiraPalette.mood(level: moodLevel).opacity(0.04),
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        }
    }
}
