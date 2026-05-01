import Foundation
import Testing
@testable import Utilities

@Suite("NotificationPreferencesStore")
struct NotificationPreferencesStoreTests {
    private func makeStore() -> (NotificationPreferencesStore, UserDefaults, String) {
        let suiteName = "tests.notifications.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let key = "prefs"
        return (NotificationPreferencesStore(defaults: defaults, key: key), defaults, suiteName)
    }

    @Test("Defaults returned when key absent")
    func defaultsWhenAbsent() {
        let (store, _, _) = makeStore()
        let prefs = store.load()
        #expect(prefs.evening.isEnabled == true)
        #expect(prefs.evening.hour == 21)
        #expect(prefs.evening.minute == 30)
        #expect(prefs.inactivity.isEnabled == true)
        #expect(prefs.inactivity.thresholdDays == 3)
        #expect(prefs.inactivity.hour == 10)
        #expect(prefs.inactivity.minute == 0)
    }

    @Test("Round-trip preserves all fields")
    func roundTrip() {
        let (store, _, _) = makeStore()
        var prefs = NotificationPreferences.default
        prefs.evening.isEnabled = false
        prefs.evening.hour = 8
        prefs.evening.minute = 15
        prefs.inactivity.isEnabled = false
        prefs.inactivity.thresholdDays = 7
        prefs.inactivity.hour = 12
        prefs.inactivity.minute = 30
        store.save(prefs)
        let loaded = store.load()
        #expect(loaded == prefs)
    }

    @Test("Corrupted payload falls back to defaults")
    func corruptedFallback() {
        let (store, defaults, _) = makeStore()
        defaults.set(Data([0xFF, 0xFE, 0xFD]), forKey: "prefs")
        let loaded = store.load()
        #expect(loaded == NotificationPreferences.default)
    }

    @Test("Saving overwrites previous value")
    func saveOverwrites() {
        let (store, _, _) = makeStore()
        var prefs = NotificationPreferences.default
        prefs.evening.hour = 7
        store.save(prefs)
        prefs.evening.hour = 22
        store.save(prefs)
        #expect(store.load().evening.hour == 22)
    }
}
