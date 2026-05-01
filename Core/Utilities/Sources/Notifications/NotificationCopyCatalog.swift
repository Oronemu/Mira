import Foundation
import CoreKit

/// Default `NotificationCopyProvider`: tries Remote Config first, falls
/// back to bundled defaults. Selection is deterministic by day-of-year so
/// the same date always gets the same copy (keeps Settings-level previews
/// honest and avoids consecutive repeats).
public struct NotificationCopyCatalog: NotificationCopyProvider {
    private let remoteConfig: (any RemoteConfigService)?
    private let calendar: Calendar

    public init(
        remoteConfig: (any RemoteConfigService)? = nil,
        calendar: Calendar = .current
    ) {
        self.remoteConfig = remoteConfig
        self.calendar = calendar
    }

    public func copy(
        for kind: LocalNotificationKind,
        on date: Date,
        locale: Locale
    ) async -> NotificationCopy {
        let language = locale.language.languageCode?.identifier ?? "en"
        let items = await items(for: kind, language: language)
        guard !items.isEmpty else {
            // Bundled defaults always include EN, so this is unreachable
            // by construction. Belt-and-braces fallback so the call site
            // never has to handle nil.
            return NotificationCopy(title: "Mira", body: "Open Mira")
        }
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = (day - 1 + items.count) % items.count
        return items[index]
    }

    private func items(
        for kind: LocalNotificationKind,
        language: String
    ) async -> [NotificationCopy] {
        let bundled = BundledCopyDefaults.items(for: kind, language: language)
        guard let remoteConfig else { return bundled }
        let key = "\(kind.remoteConfigKeyPrefix)_\(language)"
        guard let json = await remoteConfig.string(forKey: key),
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(RemoteCopyPayload.self, from: data),
              !payload.items.isEmpty else {
            return bundled
        }
        return payload.items.map { NotificationCopy(title: $0.title, body: $0.body) }
    }

    private struct RemoteCopyPayload: Decodable {
        struct Item: Decodable {
            let title: String
            let body: String
        }
        let items: [Item]
    }
}
