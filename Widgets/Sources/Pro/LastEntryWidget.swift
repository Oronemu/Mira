import SwiftUI
import WidgetKit
import DesignSystem

/// Pro-only Home Screen widget: snippet of the most recent entry plus
/// its date and mood marker. Tap → new entry.
struct LastEntryHomeWidget: Widget {
    let kind = "com.veilbytesoft.Mira.LastEntryHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider(requiresPro: true)) { entry in
            LastEntryView(entry: entry)
        }
        .configurationDisplayName("Last Entry (Pro)")
        .description("A glance at your most recent journal entry.")
        .supportedFamilies([.systemSmall])
    }
}

private struct LastEntryView: View {
    let entry: StreakEntry

    var body: some View {
        Group {
            if entry.isLocked {
                WidgetLockedView()
            } else if let latest = entry.latestEntry {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if let mood = latest.mood {
                            Circle()
                                .fill(MiraPalette.mood(level: mood.rawValue))
                                .frame(width: 8, height: 8)
                        }
                        Text(latest.createdAt, format: .dateTime.day().month())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .opacity(0.65)
                    }
                    Text(latest.plainContent)
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(URL(string: "mira://new"))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 22, weight: .semibold))
                        .opacity(0.55)
                    Text("No entries yet")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetURL(URL(string: "mira://new"))
            }
        }
        .containerBackground(for: .widget) {
            WidgetMoodBackground(moodLevel: entry.latestEntry?.mood?.rawValue)
        }
    }
}
