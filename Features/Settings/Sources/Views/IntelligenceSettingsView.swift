import SwiftUI
import CoreKit
import Utilities
import AIKit
import DesignSystem

public struct IntelligenceSettingsView: View {
    @Environment(\.aiService) private var aiService
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.modelDownloadCoordinator) private var coordinator
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter
    @State private var state: SettingsState?

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3], intensity: 0.55)

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
        .collapsibleHeroTitle("Intelligence")
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

    // MARK: - Content

    private func content(state: SettingsState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero

                providerBlock(state: state)

                if state.settings.provider == .local {
                    localBlock(state: state)
                }

                if state.settings.provider == .remote {
                    remoteBlock(state: state)
                }

                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .animation(.spring(duration: 0.4, bounce: 0.15), value: state.settings.provider)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Hero

    private var hero: some View {
        SettingsHero(
            title: "Intelligence",
            subtitle: "How Mira generates reflections and answers your questions"
        )
    }

    // MARK: - Provider

    private func providerBlock(state: SettingsState) -> some View {
        VStack(spacing: 10) {
            SettingsOptionCard(
                icon: "moon.zzz",
                title: "Off",
                subtitle: "No AI features. Reflections and Ask Mira are disabled.",
                moodLevel: 3,
                isSelected: state.settings.provider == .off
            ) {
                Task { await state.setProvider(.off) }
            }
            SettingsOptionCard(
                icon: "iphone",
                title: "On-device",
                subtitle: "Runs locally with a downloaded model. Nothing leaves the phone.",
                moodLevel: 5,
                isSelected: state.settings.provider == .local
            ) {
                Task { await state.setProvider(.local) }
            }
            SettingsOptionCard(
                icon: "cloud",
                title: "Remote",
                subtitle: "Anthropic, OpenAI or OpenRouter via your API key. Falls back to on-device if the request fails.",
                moodLevel: 2,
                isSelected: state.settings.provider == .remote
            ) {
                Task {
                    if await subscriptionService.isEntitled(to: .hostedAI) {
                        await state.setProvider(.remote)
                    } else {
                        paywallPresenter.present(.feature(.hostedAI))
                    }
                }
            }
        }
    }

    // MARK: - On-device

    private func localBlock(state: SettingsState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Model").eyebrowStyle()
            NavigationLink {
                ModelPickerView { [weak state] in await state?.reloadAI() }
            } label: {
                currentModelRow(state: state)
            }
            .buttonStyle(.plain)
        }
    }

    private func currentModelRow(state: SettingsState) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MiraPalette.primaryText.opacity(0.82))
                .frame(width: 40, height: 40)
                .background(Circle().fill(MiraPalette.mood(level: 5).opacity(0.18)))

            VStack(alignment: .leading, spacing: 4) {
                Text(state.localModel.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText)
                Text(statusText(state.localModelStatus))
                    .font(.system(size: 12))
                    .foregroundStyle(MiraPalette.secondaryText)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MiraPalette.secondaryText)
                .padding(.top, 14)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func statusText(_ status: SettingsState.LocalModelStatus) -> String {
        switch status {
        case .notDownloaded: String(localized: "Not downloaded yet")
        case .downloading(let fraction): String(format: "Downloading · %.0f%%", fraction * 100)
        case .ready: String(localized: "Ready to use")
        }
    }

    // MARK: - Remote

    @ViewBuilder
    private func remoteBlock(state: SettingsState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Service").eyebrowStyle()
                GlassPillPicker(
                    options: RemoteConfig.Provider.allCases,
                    selection: Binding(
                        get: { state.draftRemoteConfig.provider },
                        set: { newValue in Task { await state.setRemoteProvider(newValue) } }
                    ),
                    label: { $0.displayName }
                )
            }

            fieldBlock(title: "Model") {
                TextField("e.g. claude-sonnet-4-6", text: Binding(
                    get: { state.draftRemoteConfig.model },
                    set: { newValue in Task { await state.setModel(newValue) } }
                ))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))
            }

            fieldBlock(title: "API key") {
                SecureField("sk-…", text: Binding(
                    get: { state.draftAPIKey },
                    set: { state.draftAPIKey = $0 }
                ))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))
            }

            HStack(spacing: 10) {
                glassButton(
                    title: state.isKeySaving ? "Saving…" : "Save key",
                    systemImage: "key.fill",
                    isLoading: state.isKeySaving,
                    isDisabled: state.isKeySaving
                ) { Task { await state.saveAPIKey() } }

                glassButton(
                    title: state.isTestingConnection ? "Testing…" : "Test connection",
                    systemImage: "bolt.fill",
                    isLoading: state.isTestingConnection,
                    isDisabled: state.isTestingConnection || state.draftAPIKey.isEmpty
                ) { Task { await state.testConnection() } }
            }

            if let result = state.testResult {
                testResultRow(result)
            }

            Text("Keys live in the iOS Keychain on this device only. Mira falls back to the on-device model if a remote request fails.")
                .font(.system(size: 12))
                .foregroundStyle(MiraPalette.secondaryText)
                .padding(.top, 4)
        }
    }

    private func fieldBlock<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrowStyle()
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Capsule().fill(MiraPalette.secondaryBackground.opacity(0.5)))
                .overlay(Capsule().strokeBorder(MiraPalette.primaryText.opacity(0.08), lineWidth: 1))
        }
    }

    private func glassButton(
        title: String,
        systemImage: String,
        isLoading: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    @ViewBuilder
    private func testResultRow(_ result: SettingsState.TestResult) -> some View {
        switch result {
        case .ok:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MiraPalette.mood(level: 5))
                Text("Connection OK")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
            }
        case .failure(let message):
            ErrorPill(message)
        }
    }
}

