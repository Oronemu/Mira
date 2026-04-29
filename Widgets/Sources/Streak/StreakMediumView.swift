import SwiftUI
import WidgetKit
import CoreKit
import DesignSystem

struct StreakMediumView: View {
    let entry: StreakEntry

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            streakBlock
                .frame(width: 110, alignment: .leading)

            Rectangle()
                .fill(MiraPalette.primaryText.opacity(0.10))
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)

            previewBlock
        }
        .containerBackground(for: .widget) {
            WidgetMoodBackground(moodLevel: entry.latestEntry?.mood?.rawValue)
        }
        .widgetURL(URL(string: "mira://new"))
    }

    // MARK: - Streak

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Day streak").eyebrowStyle()

            Text("\(entry.streak)")
                .font(.system(size: 46, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
                .contentTransition(.numericText(value: Double(entry.streak)))
                .widgetAccentable()

            Spacer(minLength: 0)

            MoodSparkline(values: entry.moodSparkline, height: 8)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewBlock: some View {
        if let latest = entry.latestEntry {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(latest.createdAt, format: .dateTime.day().month(.abbreviated))
                        .eyebrowStyle()
                    Spacer(minLength: 0)
                    if let mood = latest.mood {
                        Text(mood.emoji)
                            .font(.system(size: 13))
                            .accessibilityLabel(mood.label)
                    }
                }
                Text(latest.content)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                    .lineSpacing(2)
                    .lineLimit(4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Start a streak").eyebrowStyle()
                Text("Tap to write your\nfirst entry.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                    .lineSpacing(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
