import SwiftUI
import CoreKit
import Utilities
import DesignSystem

/// Stats screen — pushed from Insights toolbar via `chart.bar.xaxis`.
/// Reads from entries / insights / Mira chats and renders eight cards in
/// a quiet, scrolling layout: hero mood trend → counters row → weekday
/// pattern → streak → year heatmap → engagement counters.
public struct StatsView: View {

    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.askMiraRepository) private var askMiraRepository
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter

    @State private var state: StatsState?
    @State private var status: SubscriptionStatus = .unknown

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: ambientMoodLevels, intensity: 0.55)

            Group {
                if let state {
                    scroll(state: state)
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
        .collapsibleHeroTitle("Your patterns")
        .task {
            if state == nil {
                state = StatsState(
                    entryRepository: entryRepository,
                    insightRepository: insightRepository,
                    askMiraRepository: askMiraRepository
                )
            }
            await state?.observe()
        }
        .task {
            // Drive Pro premium-section unlock state. Lives alongside
            // the observe loop above; SwiftUI runs both .task blocks
            // in parallel so neither blocks the other.
            status = await subscriptionService.status
            for await snapshot in subscriptionService.statusUpdates {
                status = snapshot
            }
        }
    }

    // MARK: - Scroll

    private func scroll(state: StatsState) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                rangePicker(state: state)

                StatsMoodTrendCard(
                    dailyAverages: state.dailyMoodAverages,
                    entryCount: state.entriesWithMoodCount,
                    overallAverage: state.averageMood
                )

                StatsMoodCountersRow(counters: state.moodCounters)

                StatsWeekdayCard(
                    weekdayMoods: state.weekdayMoods,
                    calendar: .current
                )

                StatsStreakCard(
                    streak: state.streak,
                    moodLevel: state.ambientMoodLevel
                )

                StatsYearHeatmapCard(cells: state.heatmapCells)

                premiumSection(state: state)

                engagementRow(state: state)
                askMiraCard(state: state)

                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .animation(.spring(duration: 0.4, bounce: 0.15), value: state.range)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PATTERNS · \(monthYearText)", comment: "Stats — eyebrow above the screen title")
                .eyebrowStyle()
            Text("Your patterns", comment: "Stats — screen hero title")
                .font(MiraTypography.hero)
                .foregroundStyle(MiraPalette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var monthYearText: String {
        Date.now.formatted(.dateTime.month(.wide).year()).uppercased()
    }

    // MARK: - Range picker

    private func rangePicker(state: StatsState) -> some View {
        GlassPillPicker(
            options: StatisticsCalculator.Range.allCases,
            selection: Binding(
                get: { state.range },
                set: { state.range = $0 }
            ),
            tint: MiraPalette.mood(level: state.ambientMoodLevel),
            label: rangeLabel
        )
        .padding(.bottom, 4)
    }

    private func rangeLabel(_ range: StatisticsCalculator.Range) -> String {
        switch range {
        case .week:  String(localized: "Week", comment: "Stats range picker — last 7 days")
        case .month: String(localized: "Month", comment: "Stats range picker — last 30 days")
        case .year:  String(localized: "Year", comment: "Stats range picker — last 365 days")
        }
    }

    // MARK: - Engagement row

    private func engagementRow(state: StatsState) -> some View {
        // `.fixedSize(vertical: true)` lets the HStack adopt the taller
        // child's intrinsic height, then `maxHeight: .infinity` on each
        // card stretches the shorter one to match — keeps subtitle Ys
        // aligned even when one title wraps in a longer locale (e.g. RU).
        HStack(alignment: .top, spacing: 10) {
            StatsCounterCard(
                icon: "text.alignleft",
                value: formatted(state.totalWords),
                title: "Words written",
                subtitle: rangeSubtitle(for: state.range),
                moodLevel: state.ambientMoodLevel
            )
            StatsCounterCard(
                icon: "sparkles",
                value: "\(state.insightCount)",
                title: "Reflections",
                subtitle: "received total",
                moodLevel: state.ambientMoodLevel
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func askMiraCard(state: StatsState) -> some View {
        StatsCounterCard(
            icon: "quote.bubble",
            value: "\(state.chatCount)",
            title: "Mira conversations",
            subtitle: "since you started",
            moodLevel: state.ambientMoodLevel
        )
    }

    // MARK: - Pro premium section

    /// Three Pro panels — tag correlations, weekday forecast, and a
    /// year-in-review entry point. Free users see them blurred with a
    /// single "Unlock Pro" CTA on top of the trio so the stack reads
    /// as one paywalled tier rather than three nags.
    @ViewBuilder
    private func premiumSection(state: StatsState) -> some View {
        PremiumOverlay(
            isLocked: !status.isPro,
            onUnlock: { paywallPresenter.present(.feature(.advancedStats)) }
        ) {
            VStack(spacing: 14) {
                StatsTagCorrelationCard(
                    correlations: status.isPro ? state.tagCorrelations : Self.placeholderCorrelations,
                    moodLevel: state.ambientMoodLevel
                )
                StatsForecastCard(
                    predictions: status.isPro ? state.weekdayPredictions : Self.placeholderPredictions
                )
                YearInReviewCard(
                    report: state.currentYearReport
                )
            }
        }
    }

    /// Stand-in correlations rendered behind the blur so free users see
    /// a recognisable shape rather than an empty placeholder.
    private static let placeholderCorrelations: [StatisticsCalculator.TagMoodCorrelation] = [
        .init(tag: "work",  averageMood: 3.2, count: 12),
        .init(tag: "sleep", averageMood: 4.1, count: 9),
        .init(tag: "run",   averageMood: 4.6, count: 7),
    ]

    private static let placeholderPredictions: [StatisticsCalculator.DayPrediction] = {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now
        return (0..<7).map { i in
            let day = cal.date(byAdding: .day, value: i, to: start) ?? start
            // Synthesised wave so the blurred preview shows variation.
            let mood = 2.5 + sin(Double(i) * 0.9) * 1.2
            return .init(date: day, predictedMood: mood, confidence: 0.5)
        }
    }()

    // MARK: - Helpers

    private func formatted(_ count: Int) -> String {
        count.formatted(.number)
    }

    private func rangeSubtitle(for range: StatisticsCalculator.Range) -> LocalizedStringKey {
        switch range {
        case .week:  "in the last 7 days"
        case .month: "in the last 30 days"
        case .year:  "in the last 365 days"
        }
    }

    private var ambientMoodLevels: [Int] {
        guard let level = state?.ambientMoodLevel else { return [3] }
        return [level]
    }
}
