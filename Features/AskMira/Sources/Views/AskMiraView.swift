import SwiftUI
import CoreKit
import DesignSystem
import Utilities

public struct AskMiraView: View {
    @Environment(\.askMiraRepository) private var repository
    @Environment(\.aiProvider) private var aiProvider
    @Environment(\.embeddingProvider) private var embeddingProvider
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter
    @Environment(\.scenePhase) private var scenePhase

    @State private var state: AskMiraState?
    @State private var isInfoPresented = false
    @State private var isHistoryPresented = false
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var isLocalAI = false
    @State private var lowPowerBannerDismissed = false
    @FocusState private var inputFocused: Bool

    private let onSelectEntry: (UUID) -> Void

    public init(onSelectEntry: @escaping (UUID) -> Void) {
        self.onSelectEntry = onSelectEntry
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            AmbientBackground(moodLevels: [2, 4], intensity: 0.55)

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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isInfoPresented = true
                    analyticsService.log(event: "ask_mira_info_opened")
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("About Ask Mira"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isHistoryPresented = true
                    analyticsService.log(event: "ask_mira_history_opened")
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Chat history"))
            }
        }
        .sheet(isPresented: $isInfoPresented) {
            AskMiraInfoSheet()
        }
        .sheet(isPresented: $isHistoryPresented) {
            if let state {
                AskMiraHistorySheet(
                    chats: state.chats,
                    activeChatID: state.activeChatID,
                    onOpen: { id in state.openChat(id: id) },
                    onNewChat: { state.startNewChat() },
                    onDelete: { id in Task { await state.deleteChat(id: id) } },
                    onRename: { id, title in Task { await state.renameChat(id: id, title: title) } }
                )
            }
        }
        .task {
            if state == nil {
                state = AskMiraState(
                    repository: repository,
                    aiProvider: aiProvider,
                    embeddingProvider: embeddingProvider,
                    entryRepository: entryRepository,
                    analyticsService: analyticsService
                )
            }
            refreshAISettings()
            await state?.observe()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            let enabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            // Reset dismissal when LPM turns off, so the next activation
            // shows the banner again.
            if !enabled { lowPowerBannerDismissed = false }
            isLowPowerMode = enabled
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                let enabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                if !enabled { lowPowerBannerDismissed = false }
                isLowPowerMode = enabled
                refreshAISettings()
            }
        }
    }

    private var showLowPowerBanner: Bool {
        isLocalAI && isLowPowerMode && !lowPowerBannerDismissed
    }

    private func refreshAISettings() {
        isLocalAI = AISettingsStore().load().provider == .local
    }

    /// Wraps `state.ask()` with the Pro gate. Free users on the on-device
    /// provider go straight through; users who picked Remote get the
    /// paywall instead of an unanswered request when their entitlement is
    /// missing.
    private func askWithProGate(state: AskMiraState) {
        Task {
            let provider = AISettingsStore().load().provider
            if provider == .remote {
                let isPro = await subscriptionService.isEntitled(to: .hostedAI)
                guard isPro else {
                    paywallPresenter.present(.feature(.hostedAI))
                    return
                }
            }
            await state.ask()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(state: AskMiraState) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if showLowPowerBanner {
                            LowPowerBanner(onDismiss: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    lowPowerBannerDismissed = true
                                }
                            })
                            .transition(.opacity)
                        }

                        hero(state: state)
                            .padding(.top, 4)

                        if state.activeTurns.isEmpty && !state.isAnswering && state.streamingAnswer.isEmpty {
                            suggestions(state: state)
                        }

                        ForEach(state.activeTurns) { turn in
                            AskMiraTurnView(
                                source: .snapshot(turn),
                                onSelectReference: onSelectEntry
                            )
                            .id(turn.id)
                            .transition(.opacity)
                        }

                        if state.isAnswering || !state.streamingAnswer.isEmpty {
                            AskMiraTurnView(
                                source: .streaming(
                                    question: state.streamingQuestion,
                                    answer: state.streamingAnswer,
                                    referenceIDs: state.streamingReferenceIDs
                                ),
                                onSelectReference: onSelectEntry
                            )
                            .id("streaming")
                        }

                        if let error = state.errorMessage {
                            ErrorPill(error)
                                .frame(maxWidth: .infinity)
                        }

                        Color.clear.frame(height: 92)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .animation(.easeOut(duration: 0.25), value: state.activeTurns.map(\.id))
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded { inputFocused = false }
                )
                .onChange(of: state.streamingAnswer) { _, _ in
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
                .onChange(of: state.activeTurns.count) { _, _ in
                    guard let lastID = state.activeTurns.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composer(state: state)
                .padding(.bottom, inputFocused ? 0 : MiraTabBarLayout.aboveBarInset)
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: inputFocused)
        }
        .hideTabBar(inputFocused)
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(state: AskMiraState) -> some View {
        if state.activeTurns.isEmpty && !state.isAnswering && state.streamingAnswer.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ask your journal")
                    .font(MiraTypography.hero)
                    .foregroundStyle(MiraPalette.primaryText)
                Text("A quiet conversation with what you've written")
                    .eyebrowStyle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
    }

    // MARK: - Suggestions

    private let suggestedPrompts: [(prompt: LocalizedStringKey, moodLevel: Int)] = [
        ("What themes keep appearing this month?", 5),
        ("When did I feel most at peace lately?", 4),
        ("What's been weighing on my mind?", 2),
        ("Where have I shown up strongly?", 3),
    ]

    private func suggestions(state: AskMiraState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking").eyebrowStyle()
            VStack(spacing: 10) {
                ForEach(Array(suggestedPrompts.enumerated()), id: \.offset) { _, item in
                    SuggestionChip(prompt: item.prompt, moodLevel: item.moodLevel) {
                        state.draftQuestion = resolve(item.prompt)
                        askWithProGate(state: state)
                    }
                }
            }
        }
    }

    /// LocalizedStringKey round-trip through String(localized:) so we can
    /// feed the prompt back into the state's draft field. Acceptable here
    /// because the key is a literal — no interpolation.
    private func resolve(_ key: LocalizedStringKey) -> String {
        let mirror = Mirror(reflecting: key)
        let keyString = mirror.children.first { $0.label == "key" }?.value as? String
        return keyString.map { String(localized: String.LocalizationValue($0)) } ?? ""
    }

    // MARK: - Composer

    @ViewBuilder
    private func composer(state: AskMiraState) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your journal…", text: Binding(
                get: { state.draftQuestion },
                set: { state.draftQuestion = $0 }
            ), axis: .vertical)
            .lineLimit(1...5)
            .font(.system(.body, design: .serif))
            .foregroundStyle(MiraPalette.primaryText)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 25))
            .focused($inputFocused)
            .submitLabel(.send)
            .onSubmit { askWithProGate(state: state) }

            Button {
                askWithProGate(state: state)
            } label: {
                Group {
                    if state.isAnswering {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MiraPalette.primaryText)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background {
                Circle().fill(MiraPalette.mood(level: 4).opacity(state.canAsk ? 0.28 : 0))
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .disabled(!state.canAsk)
            .animation(.spring(duration: 0.3, bounce: 0.2), value: state.canAsk)
            .sensoryFeedback(.impact(weight: .light), trigger: state.isAnswering)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}

// MARK: - Suggestion chip

private struct SuggestionChip: View {
    let prompt: LocalizedStringKey
    let moodLevel: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.mood(level: moodLevel))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(MiraPalette.mood(level: moodLevel).opacity(0.18)))

                Text(prompt)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.88))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .padding(.top, 6)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Low Power Mode banner

private struct LowPowerBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MiraPalette.mood(level: 2))
                .frame(width: 28, height: 28)
                .background(Circle().fill(MiraPalette.mood(level: 2).opacity(0.18)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Low Power Mode is on")
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(MiraPalette.primaryText)
                Text("The on-device model will be slow. Turn off Low Power Mode in iOS Settings, or switch to a remote model in the app's Settings for faster replies.")
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MiraPalette.mood(level: 2).opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(MiraPalette.mood(level: 2).opacity(0.28), lineWidth: 1)
        )
    }
}
