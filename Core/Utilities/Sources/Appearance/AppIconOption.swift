import Foundation

/// User-facing catalog of app-icon options. The primary icon (`.default`)
/// is what App Store / installers see; alternates are switched at runtime
/// via `UIApplication.setAlternateIconName(_:)`.
///
/// Asset catalog source of truth: `App/Resources/Assets.xcassets/`
/// holds one `.appiconset` per case (named `AppIcon` for default and
/// `AppIcon-<Name>` for alternates), and `App/Project.swift` lists the
/// alternate names under `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`
/// so Xcode bundles them as switchable icons.
public enum AppIconOption: String, Sendable, Hashable, CaseIterable, Codable {
    case `default`
    case neon
    case rainy
    case stars
    case sea

    /// Bundle identifier passed to `UIApplication.setAlternateIconName`.
    /// `nil` for the primary icon (the API expects `nil` to revert to it).
    public var alternateIconName: String? {
        switch self {
        case .default: return nil
        case .neon:    return "AppIcon-Neon"
        case .rainy:   return "AppIcon-Rainy"
        case .stars:   return "AppIcon-Stars"
        case .sea:     return "AppIcon-Sea"
        }
    }

    /// Regular Image Set in the asset catalog used to render the
    /// preview inside the picker. Kept distinct from the .appiconset
    /// because alternates registered via
    /// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` are emitted
    /// into `Assets.car` in a way that `UIImage(named:)` can't reach
    /// — a parallel `IconPreview-*` Image Set guarantees a working
    /// thumbnail without relying on `CFBundleIcons` lookups.
    public var previewAssetName: String {
        switch self {
        case .default: return "IconPreview-Default"
        case .neon:    return "IconPreview-Neon"
        case .rainy:   return "IconPreview-Rainy"
        case .stars:   return "IconPreview-Stars"
        case .sea:     return "IconPreview-Sea"
        }
    }

    /// Free for the default icon, Pro for everything else. Pro users
    /// can switch freely; free users see the paywall instead.
    public var isPro: Bool {
        self != .default
    }

    /// Resolves a runtime-reported `alternateIconName` (which is `nil`
    /// for the primary) back to the enum case the picker selects on.
    public static func from(alternateIconName: String?) -> AppIconOption {
        guard let alternateIconName else { return .default }
        return AppIconOption.allCases.first { $0.alternateIconName == alternateIconName } ?? .default
    }
}
