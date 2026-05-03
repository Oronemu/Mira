import SwiftUI
import WidgetKit
import DesignSystem

/// Pro-only Home Screen widget: a 7-day mood sparkline with the
/// current day's averaged mood as a tinted footer. Reuses
/// `StreakProvider` because the upstream data shape (entries +
/// sparkline + latest entry) is the same.
struct MoodTrendHomeWidget: Widget {
    let kind = "com.veilbytesoft.Mira.MoodTrendHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider(requiresPro: true)) { entry in
            MoodTrendView(entry: entry)
        }
        .configurationDisplayName("Mood Trend (Pro)")
        .description("Your mood over the last week. Tap to write a new entry.")
        .supportedFamilies([.systemMedium])
    }
}

private struct MoodTrendView: View {
    let entry: StreakEntry

    var body: some View {
        Group {
            if entry.isLocked {
                WidgetLockedView()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Mood")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .opacity(0.65)
                        Spacer()
                        if let mood = currentMood {
                            Text(String(format: "%.1f", mood))
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(MiraPalette.mood(level: max(1, min(5, Int(round(mood))))))
                        }
                    }
                    MoodSparkline(values: entry.moodSparkline, height: 26)
                    Spacer(minLength: 0)
                    weekdayAxis
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(URL(string: "mira://new"))
            }
        }
        .containerBackground(for: .widget) {
            WidgetMoodBackground(moodLevel: entry.latestEntry?.mood?.rawValue)
        }
    }

    private var currentMood: Double? {
        guard let last = entry.moodSparkline.last, let value = last else { return nil }
        return Double(value)
    }

    private var weekdayAxis: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today) ?? today
                Text(formatter.string(from: day))
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.55)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
