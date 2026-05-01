import Foundation
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` for Mira-owned alerts.
/// All text passes through `String(localized:)` or
/// `NotificationCopyProvider` so the usual xcstrings / Remote Config
/// pipelines pick up overrides.
public struct NotificationService: Sendable {
    public init() {}

    @discardableResult
    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func postReflectionReady(insightID: UUID) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Reflection ready")
        content.body = String(localized: "Your weekly reflection is waiting in Mira.")
        content.userInfo = ["insightID": insightID.uuidString]
        content.sound = .default
        // Personal reminders need to break through Sleep / DnD / Wind Down,
        // which silently swallow .active-level pushes — the journaling
        // window is exactly the time most users have a Focus active.
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "mira.reflection.\(insightID.uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Evening reminder (rolling window)

    /// Cancels stale evening requests and re-submits a 14-day rolling
    /// window of one-shot reminders, each with its own copy. Idempotent —
    /// safe to call repeatedly (e.g. on every scene activation).
    public func scheduleEveningRolling(
        time: DateComponents,
        daysAhead: Int = 14,
        copy: any NotificationCopyProvider,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .current,
        now: Date = .now
    ) async {
        let center = UNUserNotificationCenter.current()
        let prefix = LocalNotificationKind.eveningReflection.notificationIdentifierPrefix

        // Wipe whatever was scheduled before — keeps the window in sync
        // with the latest preferences and copy without diff bookkeeping.
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending.map(\.identifier).filter { $0.hasPrefix(prefix + ".") }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        let hour = time.hour ?? 21
        let minute = time.minute ?? 30
        guard let firstSlot = Self.nextSlot(
            after: now,
            hour: hour,
            minute: minute,
            calendar: calendar,
            now: now
        ) else { return }

        var added = 0
        var failed = 0
        var firstFailure: String?
        for offset in 0..<daysAhead {
            guard let triggerDate = calendar.date(byAdding: .day, value: offset, to: firstSlot) else { continue }
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let dayKey = String(
                format: "%04d-%02d-%02d",
                comps.year ?? 0,
                comps.month ?? 0,
                comps.day ?? 0
            )
            let id = "\(prefix).\(dayKey)"
            let value = await copy.copy(for: .eveningReflection, on: triggerDate, locale: locale)

            let content = UNMutableNotificationContent()
            content.title = value.title
            content.body = value.body
            content.sound = .default
            content.interruptionLevel = .timeSensitive

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            do {
                try await center.add(request)
                added += 1
            } catch {
                failed += 1
                if firstFailure == nil { firstFailure = error.localizedDescription }
            }
        }
        let firstISO = ISO8601DateFormatter().string(from: firstSlot)
        if failed == 0 {
            MiraLog.logger(.general).info(
                "notif evening scheduled: added=\(added, privacy: .public), firstSlot=\(firstISO, privacy: .public)"
            )
        } else {
            MiraLog.logger(.general).error(
                "notif evening partial: added=\(added, privacy: .public), failed=\(failed, privacy: .public), firstError=\(firstFailure ?? "?", privacy: .public)"
            )
        }
    }

    public func cancelEveningRolling() async {
        let center = UNUserNotificationCenter.current()
        let prefix = LocalNotificationKind.eveningReflection.notificationIdentifierPrefix
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix + ".") }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Inactivity nudge

    /// Schedules a single one-shot push that fires `thresholdDays` after
    /// the user's most recent entry. If `lastEntry` is nil — no entries
    /// in the journal yet — nothing is scheduled. Re-call on app launch
    /// and on scene activation; previous request is cancelled first so
    /// the timer effectively resets every time the user opens the app.
    public func scheduleInactivity(
        lastEntry: Date?,
        thresholdDays: Int,
        time: DateComponents,
        copy: any NotificationCopyProvider,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .current,
        now: Date = .now
    ) async {
        let center = UNUserNotificationCenter.current()
        let id = LocalNotificationKind.inactivity.notificationIdentifierPrefix
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard let lastEntry else { return }

        let lastDay = calendar.startOfDay(for: lastEntry)
        guard let thresholdDay = calendar.date(byAdding: .day, value: thresholdDays, to: lastDay),
              let triggerDate = Self.nextSlot(
                  after: thresholdDay,
                  hour: time.hour ?? 10,
                  minute: time.minute ?? 0,
                  calendar: calendar,
                  now: now
              )
        else { return }

        let value = await copy.copy(for: .inactivity, on: triggerDate, locale: locale)

        let content = UNMutableNotificationContent()
        content.title = value.title
        content.body = value.body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        let triggerISO = ISO8601DateFormatter().string(from: triggerDate)
        do {
            try await center.add(request)
            MiraLog.logger(.general).info(
                "notif inactivity scheduled: trigger=\(triggerISO, privacy: .public)"
            )
        } catch {
            MiraLog.logger(.general).error(
                "notif inactivity add failed: \(error.localizedDescription, privacy: .public), trigger=\(triggerISO, privacy: .public)"
            )
        }
    }

    public func cancelInactivity() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [LocalNotificationKind.inactivity.notificationIdentifierPrefix]
        )
    }

    // MARK: - Internals

    /// First moment matching `hour:minute` in `calendar`'s timezone that
    /// is on/after `baseline` and strictly after `now`. Returns nil only
    /// if Calendar arithmetic fails (shouldn't happen for valid inputs).
    static func nextSlot(
        after baseline: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar,
        now: Date
    ) -> Date? {
        let day = calendar.startOfDay(for: max(baseline, now))
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        guard let candidate = calendar.date(from: comps) else { return nil }
        if candidate > now { return candidate }
        return calendar.date(byAdding: .day, value: 1, to: candidate)
    }

}
