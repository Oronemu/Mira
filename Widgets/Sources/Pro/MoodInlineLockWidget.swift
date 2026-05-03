import SwiftUI
import WidgetKit

/// Pro-only Lock Screen accessoryInline widget — single line of text
/// surfacing today's streak and most recent mood. Lives next to the
/// time / weather rather than as a tile.
struct MoodInlineLockWidget: Widget {
    let kind = "com.veilbytesoft.Mira.MoodInlineLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider(requiresPro: true)) { entry in
            MoodInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Mira Mood (Pro)")
        .description("Today's mood and streak in a single line.")
        .supportedFamilies([.accessoryInline])
    }
}

private struct MoodInlineView: View {
    let entry: StreakEntry

    var body: some View {
        if entry.isLocked {
            WidgetLockedView()
        } else if let mood = entry.moodSparkline.last ?? nil {
            Text("✦ \(entry.streak) day · mood \(mood)")
                .widgetURL(URL(string: "mira://new"))
        } else {
            Text("✦ \(entry.streak) day streak")
                .widgetURL(URL(string: "mira://new"))
        }
    }
}
