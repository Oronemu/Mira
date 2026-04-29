import SwiftUI
import WidgetKit
import DesignSystem

struct StreakSmallView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Day streak").eyebrowStyle()

            Text("\(entry.streak)")
                .font(.system(size: 56, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
                .contentTransition(.numericText(value: Double(entry.streak)))
                .widgetAccentable()
                .padding(.top, 4)

            Spacer(minLength: 0)

            MoodSparkline(values: entry.moodSparkline)
        }
        .containerBackground(for: .widget) {
            WidgetMoodBackground(moodLevel: entry.latestEntry?.mood?.rawValue)
        }
        .widgetURL(URL(string: "mira://new"))
    }
}
