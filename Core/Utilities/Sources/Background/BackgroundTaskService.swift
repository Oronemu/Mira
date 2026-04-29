import Foundation
import BackgroundTasks

/// Thin wrapper over `BGTaskScheduler` for the weekly-reflection task.
/// The launch handler must be registered before the app finishes
/// launching — call `registerReflectionHandler(_:)` from `App.init`.
public struct BackgroundTaskService: Sendable {
    public static let reflectionIdentifier = "com.veilbytesoft.Mira.reflection.weekly"

    /// Light background refresh slot used by CloudKit sync as a fallback
    /// for silent pushes (which can be throttled by iOS when the user
    /// has Background App Refresh disabled or the app has been idle).
    public static let syncRefreshIdentifier = "com.veilbytesoft.Mira.sync.refresh"

    public init() {}

    public func registerReflectionHandler(
        _ handler: @escaping (BGProcessingTask) -> Void
    ) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.reflectionIdentifier,
            using: nil
        ) { task in
            guard let processing = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handler(processing)
        }
    }

    /// Submits the next weekly reflection task request. iOS treats
    /// `earliestBeginDate` as a hint; actual execution time depends on
    /// device conditions.
    public func scheduleWeeklyReflection(
        calendar: Calendar = .current,
        now: Date = .now
    ) throws {
        let request = BGProcessingTaskRequest(identifier: Self.reflectionIdentifier)
        request.earliestBeginDate = Self.nextSundayEvening(calendar: calendar, now: now)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try BGTaskScheduler.shared.submit(request)
    }

    /// Schedules the next reflection task according to the user's
    /// chosen frequency, or cancels the pending one when `.off`.
    public func scheduleReflection(
        for frequency: ReflectionFrequency,
        calendar: Calendar = .current,
        now: Date = .now
    ) throws {
        switch frequency {
        case .off:
            cancelReflection()
        case .weekly:
            try scheduleWeeklyReflection(calendar: calendar, now: now)
        case .biweekly:
            let next = Self.nextSundayEvening(calendar: calendar, now: now)
            let twoWeeks = calendar.date(byAdding: .day, value: 7, to: next) ?? next.addingTimeInterval(7 * 24 * 60 * 60)
            let request = BGProcessingTaskRequest(identifier: Self.reflectionIdentifier)
            request.earliestBeginDate = twoWeeks
            request.requiresNetworkConnectivity = false
            request.requiresExternalPower = false
            try BGTaskScheduler.shared.submit(request)
        }
    }

    public func cancelReflection() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.reflectionIdentifier)
    }

    /// Registers the app-refresh handler that gives the sync pipeline a
    /// chance to catch up when silent pushes haven't fired. Must be
    /// called before `App.init` returns.
    public func registerSyncRefreshHandler(
        _ handler: @escaping (BGAppRefreshTask) -> Void
    ) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.syncRefreshIdentifier,
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handler(refresh)
        }
    }

    /// Submits the next sync refresh request. iOS coalesces these with
    /// device conditions; the earliest hint means "no sooner than N
    /// minutes". 15 min matches Apple's recommended minimum for
    /// BGAppRefreshTaskRequest.
    public func scheduleSyncRefresh(now: Date = .now) throws {
        let request = BGAppRefreshTaskRequest(identifier: Self.syncRefreshIdentifier)
        request.earliestBeginDate = now.addingTimeInterval(15 * 60)
        try BGTaskScheduler.shared.submit(request)
    }

    public func cancelSyncRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.syncRefreshIdentifier)
    }

    static func nextSundayEvening(calendar: Calendar, now: Date = .now) -> Date {
        var components = DateComponents()
        components.weekday = 1 // Sunday (Gregorian)
        components.hour = 21
        components.minute = 0
        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(7 * 24 * 60 * 60)
    }
}
