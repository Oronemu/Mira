import Foundation
import Testing
import CoreKit
@testable import Utilities

@Suite("NotificationCopyCatalog")
struct NotificationCopyCatalogTests {
    private static let englishLocale = Locale(identifier: "en_US")
    private static let russianLocale = Locale(identifier: "ru_RU")

    private static func calendar(dayOfYear: Int, year: Int = 2026) -> (Calendar, Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = year
        comps.dayOfYear = dayOfYear
        let date = calendar.date(from: comps)!
        return (calendar, date)
    }

    @Test("Bundled fallback used when remote config is nil")
    func bundledFallbackNoRemoteConfig() async {
        let (cal, date) = Self.calendar(dayOfYear: 1)
        let catalog = NotificationCopyCatalog(remoteConfig: nil, calendar: cal)
        let copy = await catalog.copy(for: .eveningReflection, on: date, locale: Self.englishLocale)
        #expect(copy.title == "Quick one")
        #expect(copy.body == "Quick brain dump? 5 lines max, promise.")
    }

    @Test("Russian locale resolves to Russian bundled copy")
    func russianBundled() async {
        let (cal, date) = Self.calendar(dayOfYear: 1)
        let catalog = NotificationCopyCatalog(remoteConfig: nil, calendar: cal)
        let copy = await catalog.copy(for: .eveningReflection, on: date, locale: Self.russianLocale)
        #expect(copy.title == "Быстренько")
        #expect(copy.body == "Скинь пару мыслей, ну? 5 строк хватит.")
    }

    @Test("Unknown language falls back to English")
    func unknownLanguageFallback() async {
        let (cal, date) = Self.calendar(dayOfYear: 1)
        let catalog = NotificationCopyCatalog(remoteConfig: nil, calendar: cal)
        let copy = await catalog.copy(
            for: .eveningReflection,
            on: date,
            locale: Locale(identifier: "fr_FR")
        )
        #expect(copy.title == "Quick one")
    }

    @Test("Day-of-year selects different copy across the year")
    func deterministicRotation() async {
        let catalog = NotificationCopyCatalog(remoteConfig: nil)
        let (cal, day1) = Self.calendar(dayOfYear: 1)
        let catalog1 = NotificationCopyCatalog(remoteConfig: nil, calendar: cal)
        let copy1 = await catalog1.copy(for: .eveningReflection, on: day1, locale: Self.englishLocale)
        let (cal2, day2) = Self.calendar(dayOfYear: 2)
        let catalog2 = NotificationCopyCatalog(remoteConfig: nil, calendar: cal2)
        let copy2 = await catalog2.copy(for: .eveningReflection, on: day2, locale: Self.englishLocale)
        #expect(copy1 != copy2)

        // Same day-of-year always returns the same copy.
        let (cal3, day1Repeat) = Self.calendar(dayOfYear: 1, year: 2027)
        let catalog3 = NotificationCopyCatalog(remoteConfig: nil, calendar: cal3)
        let copy3 = await catalog3.copy(for: .eveningReflection, on: day1Repeat, locale: Self.englishLocale)
        #expect(copy1 == copy3)
        _ = catalog
    }

    @Test("Rotation wraps modulo array size")
    func rotationWraps() async {
        // Evening pool is 10 items — day 11 should map back to index 0.
        let (cal1, day1) = Self.calendar(dayOfYear: 1)
        let catalog1 = NotificationCopyCatalog(remoteConfig: nil, calendar: cal1)
        let copy1 = await catalog1.copy(for: .eveningReflection, on: day1, locale: Self.englishLocale)
        let (cal11, day11) = Self.calendar(dayOfYear: 11)
        let catalog11 = NotificationCopyCatalog(remoteConfig: nil, calendar: cal11)
        let copy11 = await catalog11.copy(for: .eveningReflection, on: day11, locale: Self.englishLocale)
        #expect(copy1 == copy11)
    }

    @Test("Inactivity bundled English copy")
    func inactivityBundled() async {
        let (cal, date) = Self.calendar(dayOfYear: 1)
        let catalog = NotificationCopyCatalog(remoteConfig: nil, calendar: cal)
        let copy = await catalog.copy(for: .inactivity, on: date, locale: Self.englishLocale)
        #expect(copy.title == "Long time")
        #expect(copy.body == "Hey, it's been a minute. How's life?")
    }

    @Test("Remote Config override replaces bundled copy when valid")
    func remoteConfigOverride() async {
        let json = """
        {"items":[{"title":"Override Title","body":"Override Body"}]}
        """
        let stub = StubRemoteConfig()
        await stub.set(json, forKey: "notif_evening_en")
        let (cal, date) = Self.calendar(dayOfYear: 1)
        let catalog = NotificationCopyCatalog(remoteConfig: stub, calendar: cal)
        let copy = await catalog.copy(for: .eveningReflection, on: date, locale: Self.englishLocale)
        #expect(copy.title == "Override Title")
        #expect(copy.body == "Override Body")
    }

    @Test("Invalid Remote Config JSON falls back to bundled")
    func remoteConfigInvalidJSON() async {
        let stub = StubRemoteConfig()
        await stub.set("{not valid", forKey: "notif_evening_en")
        let (cal, date) = Self.calendar(dayOfYear: 1)
        let catalog = NotificationCopyCatalog(remoteConfig: stub, calendar: cal)
        let copy = await catalog.copy(for: .eveningReflection, on: date, locale: Self.englishLocale)
        #expect(copy.title == "Quick one")
    }

    @Test("Empty items array in Remote Config falls back to bundled")
    func remoteConfigEmptyItems() async {
        let stub = StubRemoteConfig()
        await stub.set("{\"items\":[]}", forKey: "notif_evening_en")
        let (cal, date) = Self.calendar(dayOfYear: 1)
        let catalog = NotificationCopyCatalog(remoteConfig: stub, calendar: cal)
        let copy = await catalog.copy(for: .eveningReflection, on: date, locale: Self.englishLocale)
        #expect(copy.title == "Quick one")
    }

    @Test("Remote Config key includes language suffix")
    func remoteConfigPerLanguage() async {
        let stub = StubRemoteConfig()
        await stub.set("{\"items\":[{\"title\":\"EN-RC\",\"body\":\"en\"}]}", forKey: "notif_evening_en")
        await stub.set("{\"items\":[{\"title\":\"RU-RC\",\"body\":\"ru\"}]}", forKey: "notif_evening_ru")
        let (cal, date) = Self.calendar(dayOfYear: 1)
        let catalog = NotificationCopyCatalog(remoteConfig: stub, calendar: cal)
        let en = await catalog.copy(for: .eveningReflection, on: date, locale: Self.englishLocale)
        let ru = await catalog.copy(for: .eveningReflection, on: date, locale: Self.russianLocale)
        #expect(en.title == "EN-RC")
        #expect(ru.title == "RU-RC")
    }
}

// MARK: - Test stubs

private actor StubRemoteConfig: RemoteConfigService {
    private var values: [String: String] = [:]

    func set(_ value: String?, forKey key: String) {
        values[key] = value
    }

    func setDefaults(_ defaults: [String: RemoteConfigDefaultValue]) async {}

    func fetchAndActivate() async throws -> Bool { false }

    func string(forKey key: String) async -> String? { values[key] }

    func bool(forKey key: String) async -> Bool { false }

    func int(forKey key: String) async -> Int { 0 }

    func double(forKey key: String) async -> Double { 0 }
}
