import SwiftUI
import CoreKit
import Utilities
import AIKit
import DesignSystem

public struct SyncSettingsView: View {
    @Environment(\.aiService) private var aiService
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.modelDownloadCoordinator) private var coordinator
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter
    @Environment(\.syncService) private var syncService
    @State private var state: SettingsState?

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [2], intensity: 0.5)

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
        .collapsibleHeroTitle("iCloud sync")
        .task {
            if state == nil {
                state = SettingsState(
                    service: aiService,
                    syncService: syncService,
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
                    title: "iCloud sync",
                    subtitle: "Keep your journal in sync across devices"
                )

                toggleCard(state: state)

                if state.sync.isEnabled {
                    syncActions(state: state)
                }

                Text("Payloads are encrypted on this device before upload. Disabling sync rotates the key so a future re-enable starts clean.")
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .lineSpacing(2)

                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .animation(.spring(duration: 0.4, bounce: 0.15), value: state.sync.isEnabled)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Pieces

    private func toggleCard(state: SettingsState) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "icloud")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                .frame(width: 40, height: 40)
                .background(Circle().fill(MiraPalette.mood(level: 2).opacity(0.18)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Enable iCloud sync")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                Text("End-to-end encrypted. Uses your personal iCloud — we never see the content.")
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { state.sync.isEnabled },
                set: { value in Task { await state.setSyncEnabled(value) } }
            ))
            .labelsHidden()
            .tint(MiraPalette.mood(level: 2))
            .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func syncActions(state: SettingsState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            statusRow(state: state)

            SettingsGlassAction(
                title: state.isSyncing ? "Syncing…" : "Sync now",
                systemImage: "arrow.triangle.2.circlepath",
                isLoading: state.isSyncing,
                isDisabled: state.isSyncing,
                tintLevel: 2
            ) { Task { await state.syncNow() } }
        }
    }

    private func statusRow(state: SettingsState) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Status").eyebrowStyle()
            Spacer()
            statusValue(state.syncStatus)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func statusValue(_ status: SyncStatus) -> some View {
        switch status {
        case .idle:
            Text("Up to date")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MiraPalette.secondaryText)
        case .syncing:
            Text("Syncing…")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MiraPalette.secondaryText)
        case .succeeded(let date):
            // Refresh once a minute so "just now" rolls forward into
            // "a minute ago", "5 minutes ago", etc. without requiring
            // the user to re-enter the screen.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(relativeSyncText(date: date, now: context.date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MiraPalette.mood(level: 5))
            }
        case .failed(let message):
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.red.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
    }

    /// Renders the "time since last sync" label. Within a 10-second
    /// window we say "Just now" — the system formatter would otherwise
    /// round to "in 0 seconds" right after a successful sync (and even
    /// invert the sign on minor clock skew).
    private func relativeSyncText(date: Date, now: Date) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 10 {
            return String(localized: "Just now")
        }
        return date.formatted(.relative(presentation: .named))
    }
}
