import SwiftUI
import WidgetKit
import DesignSystem

/// Shown by Pro widgets when the user is on the free tier. Tap routes
/// to `mira://paywall` so the host app can raise the paywall sheet
/// with the `.extraWidgets` headline.
struct WidgetLockedView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("✦ Mira Pro")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
            case .accessoryRectangular:
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Unlock Mira Pro")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            default:
                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.tint)
                    Text("Unlock Mira Pro")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .multilineTextAlignment(.center)
                    Text("Tap to subscribe")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .widgetURL(URL(string: "mira://paywall"))
    }
}
