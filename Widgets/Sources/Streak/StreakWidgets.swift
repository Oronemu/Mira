import SwiftUI
import WidgetKit
import DesignSystem

struct StreakHomeWidget: Widget {
    let kind = "com.veilbytesoft.Mira.StreakHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakHomeView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("See your current writing streak and jump into a new entry.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StreakHomeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        switch family {
        case .systemMedium:
            StreakMediumView(entry: entry)
        default:
            StreakSmallView(entry: entry)
        }
    }
}

struct StreakLockWidget: Widget {
    let kind = "com.veilbytesoft.Mira.StreakLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider(requiresPro: true)) { entry in
            StreakLockView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Mira Streak (Pro)")
        .description("Your writing streak on the Lock Screen. Requires Mira Pro.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct StreakLockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        if entry.isLocked {
            WidgetLockedView()
        } else {
            switch family {
            case .accessoryRectangular:
                StreakLockRectangularView(entry: entry)
            default:
                StreakLockCircularView(entry: entry)
            }
        }
    }
}

private struct StreakLockCircularView: View {
    let entry: StreakEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -1) {
                Text("\(entry.streak)")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .contentTransition(.numericText(value: Double(entry.streak)))
                Text("days")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .opacity(0.75)
            }
        }
        .widgetURL(URL(string: "mira://new"))
    }
}

private struct StreakLockRectangularView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "book.closed")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.8)
                Text("\(entry.streak)")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .contentTransition(.numericText(value: Double(entry.streak)))
                Text("day streak")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .opacity(0.75)
            }

            MoodSparkline(values: entry.moodSparkline, height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "mira://new"))
    }
}
