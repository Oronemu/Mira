import SwiftUI

public struct TabBarVisibilityPreferenceKey: PreferenceKey {
    public static let defaultValue: Bool = true

    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value && nextValue()
    }
}

public extension View {
    /// Signals the enclosing custom tab bar to hide itself while this view is on screen.
    /// Propagates via `PreferenceKey`, so the topmost screen in a `NavigationStack` wins.
    func hideTabBar(_ hidden: Bool = true) -> some View {
        preference(key: TabBarVisibilityPreferenceKey.self, value: !hidden)
    }
}

/// Layout constants shared between the floating tab bar and the tabs that must
/// reserve space for it (e.g. bottom composer in Ask Mira).
public enum MiraTabBarLayout {
    /// Bottom safe-area padding for scrollable tab content so the last items clear
    /// the floating tab bar with breathing room.
    public static let reservedHeight: CGFloat = 76

    /// Bottom inset for a fixed action bar (e.g. Ask Mira composer) that should
    /// sit immediately above the floating tab bar with a minimal visual gap.
    public static let aboveBarInset: CGFloat = 54
}
