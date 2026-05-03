import SwiftUI
import Observation

/// Shared, app-wide appearance state. Owned by `MiraApp` and injected into
/// the environment so both the root view (to apply `.preferredColorScheme`
/// and `.tint`) and `AppearanceSettingsView` (to mutate the selection) see
/// the same source of truth. Changes propagate instantly via Observation.
///
/// Not @MainActor so it can serve as a synchronous EnvironmentKey default.
/// Mutations happen from the UI layer on main, and UserDefaults is itself
/// thread-safe — no shared mutable state escapes this class.
@Observable
public final class AppearanceState: @unchecked Sendable {
    public private(set) var settings: AppearanceSettings

    private let store: AppearanceSettingsStore

    public init(store: AppearanceSettingsStore = AppearanceSettingsStore()) {
        self.store = store
        self.settings = store.load()
    }

    public var theme: AppearanceTheme { settings.theme }
    public var accent: AccentTint { settings.accent }

    /// Maps theme to SwiftUI's color scheme modifier. `nil` means follow the
    /// system — which is what `.preferredColorScheme(nil)` does.
    public var colorScheme: ColorScheme? {
        switch settings.theme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    public func setTheme(_ theme: AppearanceTheme) {
        var next = settings
        next.theme = theme
        settings = next
        store.save(next)
    }

    public func setAccent(_ accent: AccentTint) {
        var next = settings
        next.accent = accent
        // Selecting a free accent clears any Pro overrides so the row
        // the user just tapped is visibly the active one.
        next.proAccent = nil
        next.customAccentHex = nil
        settings = next
        store.save(next)
    }

    public func setProAccent(_ accent: ProAccent) {
        var next = settings
        next.proAccent = accent
        next.customAccentHex = nil
        settings = next
        store.save(next)
    }

    /// Hex must be `#RRGGBB` or `RRGGBB`. Caller is responsible for
    /// validating with `UIColor(hexString:)` before calling — invalid
    /// strings are persisted as-is and resolution falls back to mood.
    public func setCustomAccent(hex: String) {
        var next = settings
        next.customAccentHex = hex
        next.proAccent = nil
        settings = next
        store.save(next)
    }

    /// Clears Pro overrides without changing the underlying free
    /// `accent`. Used when an entitlement lapses and we want the UI to
    /// fall back gracefully without losing the user's prior free pick.
    public func clearProOverrides() {
        guard settings.proAccent != nil || settings.customAccentHex != nil else { return }
        var next = settings
        next.proAccent = nil
        next.customAccentHex = nil
        settings = next
        store.save(next)
    }
}

private struct AppearanceStateKey: EnvironmentKey {
    static let defaultValue = AppearanceState()
}

public extension EnvironmentValues {
    var appearanceState: AppearanceState {
        get { self[AppearanceStateKey.self] }
        set { self[AppearanceStateKey.self] = newValue }
    }
}
