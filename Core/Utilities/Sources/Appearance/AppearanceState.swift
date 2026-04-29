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
