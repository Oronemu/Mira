import SwiftUI
import Observation
import CoreKit

/// App-wide privacy / terms link state. Bundled URLs are the source of
/// truth at boot; Remote Config can override them at runtime so we can
/// move the legal pages without shipping an update. Use sites read the
/// URLs synchronously through the environment.
///
/// Keys follow the existing `<prefix>_<lang>` convention used by
/// `NotificationCopyCatalog` so the Firebase Console stays consistent.
///
/// Not @MainActor so it can serve as a synchronous EnvironmentKey
/// default. The only writer is `refresh(from:locale:)` which is
/// @MainActor; SwiftUI views read from the same actor — no data race.
@Observable
public final class LegalLinks: @unchecked Sendable {
    public private(set) var privacyURL: URL
    public private(set) var termsURL: URL

    public static let privacyKeyPrefix = "legal_privacy_url"
    public static let termsKeyPrefix = "legal_terms_url"

    private static let bundledPrivacy: [String: URL] = [
        "en": URL(string: "https://mira-diary.com/privacy/")!,
        "ru": URL(string: "https://mira-diary.com/ru/privacy/")!,
    ]

    private static let bundledTerms: [String: URL] = [
        "en": URL(string: "https://mira-diary.com/terms/")!,
        "ru": URL(string: "https://mira-diary.com/ru/terms/")!,
    ]

    public init(locale: Locale = .current) {
        let lang = Self.normalizedLanguage(locale)
        self.privacyURL = Self.bundled(.privacy, lang: lang)
        self.termsURL = Self.bundled(.terms, lang: lang)
    }

    /// Replace the URLs with whatever Remote Config currently has for the
    /// given locale. Falls back to the bundled defaults if a remote value
    /// is missing or not a valid URL.
    @MainActor
    public func refresh(
        from remoteConfig: any RemoteConfigService,
        locale: Locale = .current
    ) async {
        let lang = Self.normalizedLanguage(locale)
        privacyURL = await Self.resolve(.privacy, lang: lang, remoteConfig: remoteConfig)
        termsURL = await Self.resolve(.terms, lang: lang, remoteConfig: remoteConfig)
    }

    /// Defaults to seed `RemoteConfigService.setDefaults(_:)` with at
    /// startup. Includes both languages so reads return sensible values
    /// even before the first successful fetch.
    public static var remoteConfigDefaults: [String: RemoteConfigDefaultValue] {
        var defaults: [String: RemoteConfigDefaultValue] = [:]
        for (lang, url) in bundledPrivacy {
            defaults["\(privacyKeyPrefix)_\(lang)"] = .string(url.absoluteString)
        }
        for (lang, url) in bundledTerms {
            defaults["\(termsKeyPrefix)_\(lang)"] = .string(url.absoluteString)
        }
        return defaults
    }

    private enum Kind { case privacy, terms }

    private static func normalizedLanguage(_ locale: Locale) -> String {
        locale.language.languageCode?.identifier == "ru" ? "ru" : "en"
    }

    private static func bundled(_ kind: Kind, lang: String) -> URL {
        let table = kind == .privacy ? bundledPrivacy : bundledTerms
        return table[lang] ?? table["en"]!
    }

    private static func resolve(
        _ kind: Kind,
        lang: String,
        remoteConfig: any RemoteConfigService
    ) async -> URL {
        let prefix = kind == .privacy ? privacyKeyPrefix : termsKeyPrefix
        if let raw = await remoteConfig.string(forKey: "\(prefix)_\(lang)"),
           let url = URL(string: raw) {
            return url
        }
        return bundled(kind, lang: lang)
    }
}

private struct LegalLinksKey: EnvironmentKey {
    static let defaultValue = LegalLinks()
}

public extension EnvironmentValues {
    var legalLinks: LegalLinks {
        get { self[LegalLinksKey.self] }
        set { self[LegalLinksKey.self] = newValue }
    }
}
