import Foundation
import WidgetKit
import CoreKit

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let latestEntry: EntrySnapshot?
    /// Last 7 days (oldest → newest). Each element is the rounded average
    /// mood level (1…5) for that calendar day, or `nil` when no mood was
    /// logged. Drives the sparkline decoration in the redesigned widget.
    let moodSparkline: [Int?]
    /// `true` when the user is on the free tier and the widget should
    /// render `WidgetLockedView` instead of its real content. Only Pro
    /// widgets ever flip this; the Home Streak widget keeps it `false`.
    let isLocked: Bool

    static let placeholder = StreakEntry(
        date: .now,
        streak: 0,
        latestEntry: nil,
        moodSparkline: Array(repeating: nil, count: 7),
        isLocked: false
    )
}
