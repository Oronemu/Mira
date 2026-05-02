import SwiftUI
import CoreKit
import Utilities
import AIKit
import DesignSystem

public struct ReflectionSettingsView: View {
    @Environment(\.aiService) private var aiService
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.modelDownloadCoordinator) private var coordinator
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter
    @State private var state: SettingsState?

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [4], intensity: 0.5)

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
        .hideTabBar()
        .collapsibleHeroTitle("Reflections")
        .task {
            if state == nil {
                state = SettingsState(
                    service: aiService,
                    entryRepository: entryRepository,
                    insightRepository: insightRepository,
                    coordinator: coordinator,
                    analyticsService: analyticsService,
                    crashReporter: crashReporter
                )
            }
            await state?.refresh()
        }
    }

    private func content(state: SettingsState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsHero(
                    title: "Reflections",
                    subtitle: "How often Mira drafts a reflection for you"
                )

                VStack(spacing: 10) {
                    SettingsOptionCard(
                        icon: "moon.zzz",
                        title: "Off",
                        subtitle: "No scheduled reflections. Tap below to generate one on demand.",
                        moodLevel: 3,
                        isSelected: state.reflection.frequency == .off
                    ) { state.setReflectionFrequency(.off) }

                    SettingsOptionCard(
                        icon: "calendar",
                        title: "Weekly",
                        subtitle: "Runs in the background every Sunday evening.",
                        moodLevel: 4,
                        isSelected: state.reflection.frequency == .weekly
                    ) { state.setReflectionFrequency(.weekly) }

                    SettingsOptionCard(
                        icon: "calendar.badge.clock",
                        title: "Biweekly",
                        subtitle: "Runs every other Sunday — a gentler cadence.",
                        moodLevel: 2,
                        isSelected: state.reflection.frequency == .biweekly
                    ) { state.setReflectionFrequency(.biweekly) }
                }
                .animation(.spring(duration: 0.35, bounce: 0.2), value: state.reflection.frequency)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Generate now").eyebrowStyle()

                    SettingsGlassAction(
                        title: state.isGeneratingReflection ? "Generating…" : "Draft a reflection",
                        systemImage: "sparkles",
                        isLoading: state.isGeneratingReflection,
                        isDisabled: state.isGeneratingReflection,
                        tintLevel: 4
                    ) { Task { await state.generateReflectionNow() } }
                }

                if let error = state.reflectionError {
                    ErrorPill(error)
                }

                Text("Mira reads your last week of entries and writes a short reflection. It runs locally if you're on the on-device model, otherwise through your configured remote provider.")
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
}
