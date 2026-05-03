import SwiftUI
import WidgetKit

@main
struct MiraWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Free tier
        StreakHomeWidget()
        // Pro tier — guarded by WidgetEntitlementsStore inside each
        // provider so they degrade to a `WidgetLockedView` when the
        // user isn't subscribed.
        StreakLockWidget()
        MoodTrendHomeWidget()
        LastEntryHomeWidget()
        MoodInlineLockWidget()
    }
}
