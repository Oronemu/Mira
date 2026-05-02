import SwiftUI
import CoreKit
import Utilities
import DesignSystem

public struct NotificationSettingsView: View {
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.remoteConfigService) private var remoteConfigService
    @State private var prefs: NotificationPreferences = NotificationPreferencesStore().load()

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [4], intensity: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SettingsHero(
                        title: "Reminders",
                        subtitle: "Local pushes — daily check-in and a nudge if you've been quiet"
                    )

                    eveningSection
                    inactivitySection

                    Text("Local pushes only — they never leave this device. Times use your phone's clock.")
                        .font(.system(size: 12))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .lineSpacing(2)

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .collapsibleHeroTitle("Reminders")
        .onChange(of: prefs) { _, newValue in
            NotificationPreferencesStore().save(newValue)
            Task { await reschedule(newValue) }
        }
    }

    // MARK: - Sections

    private var eveningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evening reminder").eyebrowStyle()

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $prefs.evening.isEnabled) {
                    rowLabel(
                        title: "Daily check-in",
                        subtitle: "A small prompt to write down the day"
                    )
                }
                .tint(MiraPalette.mood(level: 4))

                if prefs.evening.isEnabled {
                    DatePicker(
                        "Time",
                        selection: eveningTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .tint(MiraPalette.mood(level: 4))
                    .font(.system(size: 14))
                    .foregroundStyle(MiraPalette.primaryText)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var inactivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("If you've been quiet").eyebrowStyle()

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $prefs.inactivity.isEnabled) {
                    rowLabel(
                        title: "Gentle nudge",
                        subtitle: "After a few days without an entry"
                    )
                }
                .tint(MiraPalette.mood(level: 2))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Helpers

    private func rowLabel(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(MiraPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    private var eveningTimeBinding: Binding<Date> {
        Binding(
            get: {
                // Anchor to today so Calendar gets a fully-specified date —
                // hour/minute alone resolve to year 0001 with whatever
                // historical timezone offset that era had, which can drift
                // the displayed minute by a non-trivial amount.
                let calendar = Calendar.current
                var comps = calendar.dateComponents([.year, .month, .day], from: Date())
                comps.hour = prefs.evening.hour
                comps.minute = prefs.evening.minute
                return calendar.date(from: comps) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                prefs.evening.hour = comps.hour ?? 21
                prefs.evening.minute = comps.minute ?? 30
            }
        )
    }

    private func reschedule(_ prefs: NotificationPreferences) async {
        let catalog = NotificationCopyCatalog(remoteConfig: remoteConfigService)
        let service = NotificationService()

        if prefs.evening.isEnabled {
            await service.scheduleEveningRolling(
                time: DateComponents(hour: prefs.evening.hour, minute: prefs.evening.minute),
                copy: catalog
            )
        } else {
            await service.cancelEveningRolling()
        }

        if prefs.inactivity.isEnabled {
            var query = EntryQuery.all
            query.limit = 1
            let snapshots = try? await entryRepository.fetch(matching: query)
            await service.scheduleInactivity(
                lastEntry: snapshots?.first?.createdAt,
                thresholdDays: prefs.inactivity.thresholdDays,
                time: DateComponents(hour: prefs.inactivity.hour, minute: prefs.inactivity.minute),
                copy: catalog
            )
        } else {
            await service.cancelInactivity()
        }
    }
}
