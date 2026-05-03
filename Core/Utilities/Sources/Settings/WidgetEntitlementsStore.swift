import Foundation

/// Tiny App-Group-backed view of the user's Pro entitlement that the
/// widget extension can read without going through StoreKit. The main
/// app writes the flag whenever `SubscriptionService.statusUpdates`
/// fires; widget providers read it on each timeline refresh and route
/// to a "locked" placeholder when the user isn't Pro.
///
/// Kept in `Utilities` so both the main app and the widget extension
/// (both of which already depend on `Utilities`) reach the same code.
public struct WidgetEntitlementsStore: @unchecked Sendable {
    private let defaults: UserDefaults?
    private let key: String

    public init(
        appGroup: String = "group.com.veilbytesoft.Mira",
        key: String = "widget.isPro"
    ) {
        self.defaults = UserDefaults(suiteName: appGroup)
        self.key = key
    }

    public func isPro() -> Bool {
        defaults?.bool(forKey: key) ?? false
    }

    public func setIsPro(_ value: Bool) {
        defaults?.set(value, forKey: key)
    }
}
