import SwiftUI
import CoreKit
import Utilities
import DesignSystem

public struct CalendarView: View {
    @Environment(\.entryRepository) private var repository
    @Environment(\.analyticsService) private var analyticsService

    @State private var state: CalendarState?

    private let onSelectDay: (Date) -> Void

    public init(onSelectDay: @escaping (Date) -> Void = { _ in }) {
        self.onSelectDay = onSelectDay
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)

            Group {
                if let state {
                    content(state: state)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            if state == nil {
                state = CalendarState(repository: repository, analyticsService: analyticsService)
            }
            await state?.observe()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(state: CalendarState) -> some View {
        VStack(spacing: 18) {
            monthHero(state: state)

            TabView(selection: monthSelection(state: state)) {
                ForEach(state.availableMonths, id: \.self) { month in
                    CalendarHeatmapView(month: month, state: state, onSelectDay: onSelectDay)
                        .tag(month)
                        .padding(.horizontal, 14)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            monthStats(state: state)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .padding(.top, 4)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: state.currentMonth)
    }

    // MARK: - Hero

    private func monthHero(state: CalendarState) -> some View {
        HStack(alignment: .center, spacing: 12) {
            navButton(systemName: "chevron.left", enabled: state.canGoToPreviousMonth) {
                state.goToPreviousMonth()
            }

            VStack(alignment: .center, spacing: 2) {
                Text(state.currentMonth, format: .dateTime.month(.wide))
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                    .contentTransition(.opacity)
                Text(state.currentMonth, format: .dateTime.year())
                    .eyebrowStyle()
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)

            navButton(systemName: "chevron.right", enabled: state.canGoToNextMonth) {
                state.goToNextMonth()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .sensoryFeedback(.selection, trigger: enabled)
    }

    // MARK: - Stats

    private func monthStats(state: CalendarState) -> some View {
        let entries = state.entriesInMonth(state.currentMonth)
        let avg = MoodAnalytics.averageMood(entries: entries)
        let active = state.activeDaysInMonth(state.currentMonth)

        return HStack(spacing: 10) {
            StatTile(
                icon: "doc.text",
                label: "Entries",
                value: "\(entries.count)",
                moodLevel: 2
            )
            StatTile(
                icon: "chart.bar.fill",
                label: "Avg mood",
                value: avg.map { String(format: "%.1f", $0) } ?? "—",
                moodLevel: avg.map { max(1, min(5, Int(round($0)))) } ?? 3
            )
            StatTile(
                icon: "calendar.badge.checkmark",
                label: "Active days",
                value: "\(active)",
                moodLevel: 5
            )
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: entries.count)
    }

    // MARK: - Helpers

    private func monthSelection(state: CalendarState) -> Binding<Date> {
        Binding(
            get: { state.currentMonth },
            set: { state.currentMonth = $0 }
        )
    }

    /// Ambient palette: derive from the moods present in the currently
    /// visible month so the screen's tone follows what the user is looking
    /// at. Falls back to neutral when the month is empty.
    private var ambientMoodLevels: [Int] {
        guard let state else { return [3] }
        let entries = state.entriesInMonth(state.currentMonth)
        let moods = entries.compactMap { $0.mood?.rawValue }
        return moods.isEmpty ? [3] : moods
    }
}

// MARK: - Stat tile

private struct StatTile: View {
    let icon: String
    let label: LocalizedStringKey
    let value: String
    let moodLevel: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MiraPalette.mood(level: moodLevel))
                Text(label).eyebrowStyle()
            }
            Text(value)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(MiraPalette.primaryText)
                .contentTransition(.numericText())
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}
