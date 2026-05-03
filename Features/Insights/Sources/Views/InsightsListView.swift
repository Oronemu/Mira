import SwiftUI
import CoreKit
import Utilities
import DesignSystem

public struct InsightsListView: View {
    @Environment(\.paywallPresenter) private var paywallPresenter
    @Environment(\.subscriptionService) private var subscriptionService

    /// State is owned by `RootView` so manual reflection generation
    /// continues across tab switches and the screen doesn't reset every
    /// time the view rebuilds.
    private let state: InsightsListState

    @State private var pendingDeletionID: UUID?

    private let onSelectInsight: (UUID) -> Void
    private let onOpenStats: () -> Void

    public init(
        state: InsightsListState,
        onSelectInsight: @escaping (UUID) -> Void,
        onOpenStats: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onSelectInsight = onSelectInsight
        self.onOpenStats = onOpenStats
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.7)

            scroll(state: state)
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenStats) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.85))
                }
                .accessibilityLabel(Text("Open stats", comment: "Insights toolbar — opens the Stats screen"))
            }
        }
        .collapsibleHeroTitle(
            Text("Reflections"),
            subtitle: insightsSubtitleText
        )
        .confirmationDialog(
            "Delete this reflection?",
            isPresented: deletionPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeletionID {
                    Task { await state.delete(id: id) }
                }
                pendingDeletionID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletionID = nil }
        }
    }

    // MARK: - Scroll

    @ViewBuilder
    private func scroll(state: InsightsListState) -> some View {
        if state.insights.isEmpty {
            // Empty path stays out of ScrollView so the placeholder can
            // anchor at the visual center of the screen rather than at
            // the top of an empty scroll view.
            VStack(spacing: 0) {
                hero(state: state)
                if let error = state.errorMessage {
                    ErrorPill(error)
                        .frame(maxWidth: .infinity)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                        .padding(.top, 16)
                }
                Spacer(minLength: 0)
                emptyState(state: state)
                Spacer(minLength: 0)
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(duration: 0.3, bounce: 0.2), value: state.errorMessage)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    hero(state: state)

                    if let error = state.errorMessage {
                        ErrorPill(error)
                            .frame(maxWidth: .infinity)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reflections").eyebrowStyle()
                        VStack(spacing: 12) {
                            ForEach(state.insights) { insight in
                                InsightCard(insight: insight) {
                                    onSelectInsight(insight.id)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        pendingDeletionID = insight.id
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity.combined(with: .scale(scale: 0.95))
                                ))
                            }
                        }
                    }

                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .animation(.spring(duration: 0.4, bounce: 0.15),
                           value: state.insights.map(\.id))
                .animation(.spring(duration: 0.3, bounce: 0.2),
                           value: state.errorMessage)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var insightsSubtitleText: Text {
        let count = state.insights.count
        let month = Date.now.formatted(.dateTime.month(.wide).year())
        return Text("\(count) reflections · \(month)")
    }

    // MARK: - Hero

    private func hero(state: InsightsListState) -> some View {
        let count = state.insights.count
        let month = Date.now.formatted(.dateTime.month(.wide).year())
        return VStack(alignment: .leading, spacing: 6) {
            Text("Reflections")
                .font(MiraTypography.hero)
                .foregroundStyle(MiraPalette.primaryText)
            Text("\(count) reflections · \(month)")
                .eyebrowStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Empty

    private func emptyState(state: InsightsListState) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(MiraPalette.secondaryText.opacity(0.7))
            Text("No reflections yet")
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
            Text("Weekly reflections arrive on Sunday evenings.")
                .font(MiraTypography.body)
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)

            generateButton(state: state)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    private func generateButton(state: InsightsListState) -> some View {
        Button {
            generateWithProGate(state: state)
        } label: {
            HStack(spacing: 8) {
                if state.isGenerating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text("Generate now")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(MiraPalette.primaryText)
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(
            Capsule().fill(MiraPalette.mood(level: 3).opacity(0.25))
        )
        .glassEffect(.regular.interactive(), in: Capsule())
        .disabled(state.isGenerating)
        .sensoryFeedback(.impact(weight: .light), trigger: state.isGenerating)
        .accessibilityLabel("Generate reflection now")
    }

    /// Wraps `state.generateNow()` with the Pro gate. The on-device
    /// provider stays free; users on Remote without Pro see the paywall
    /// instead of triggering a provider-failure error.
    private func generateWithProGate(state: InsightsListState) {
        Task {
            let provider = AISettingsStore().load().provider
            if provider == .remote {
                let isPro = await subscriptionService.isEntitled(to: .hostedAI)
                guard isPro else {
                    paywallPresenter.present(.feature(.hostedAI))
                    return
                }
            }
            await state.generateNow()
        }
    }

    // MARK: - Helpers

    private var deletionPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletionID != nil },
            set: { if !$0 { pendingDeletionID = nil } }
        )
    }

    /// Ambient tint for the screen — follows the user's average accent so
    /// the reflections feel anchored in the same palette as the rest of
    /// the app. Stats screen carries the per-period mood ambient now.
    private var ambientMoodLevels: [Int] { [3] }
}

// MARK: - Insight card

private struct InsightCard: View {
    let insight: InsightSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(insight.createdAt, format: .dateTime.day().month(.abbreviated).year())
                        .eyebrowStyle()
                    Text(insight.title)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(attributedPreview(insight.body))
                        .font(MiraTypography.entryBody)
                        .foregroundStyle(MiraPalette.primaryText.opacity(0.75))
                        .lineLimit(3)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MiraPalette.secondaryText)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(PressableCardStyle())
    }

    /// AI reflections may include markdown — render as AttributedString so
    /// the preview doesn't show raw `**` / `*` characters.
    private func attributedPreview(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

