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
    case calm
    case solace
    case quiet
    case reflect
    case stoic
    case editorial
    case minimal

    /// Bundle identifier passed to `UIApplication.setAlternateIconName`.
    /// `nil` for the primary icon (the API expects `nil` to revert to it).
    public var alternateIconName: String? {
        switch self {
        case .default:   return nil
        case .calm:      return "AppIcon-Calm"
        case .solace:    return "AppIcon-Solace"
        case .quiet:     return "AppIcon-Quiet"
        case .reflect:   return "AppIcon-Reflect"
        case .stoic:     return "AppIcon-Stoic"
        case .editorial: return "AppIcon-Editorial"
        case .minimal:   return "AppIcon-Minimal"
        }
    }

    /// Asset catalog name of the .appiconset to render as a preview
    /// inside the picker. Distinct from `alternateIconName` only for the
    /// primary, where the runtime switch wants `nil` but the preview
    /// still needs the asset.
    public var previewAssetName: String {
        switch self {
        case .default: return "AppIcon"
        default:       return alternateIconName ?? "AppIcon"
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
