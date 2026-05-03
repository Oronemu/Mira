import SwiftUI
import CoreKit
import DesignSystem
import Utilities
import FeatureEntryList
import FeatureEntryEditor
import FeatureEntryDetail
import FeatureAskMira
import FeatureInsights
import FeatureSettings
import FeatureStats

struct RootView: View {
    @Environment(\.appearanceState) private var appearanceState

    // Repositories / services pulled here so the long-lived feature
    // states below can be constructed once and survive tab switches.
    @Environment(\.askMiraRepository) private var askMiraRepository
    @Environment(\.insightRepository) private var insightRepository
    @Environment(\.entryRepository) private var entryRepository
    @Environment(\.aiProvider) private var aiProvider
    @Environment(\.embeddingProvider) private var embeddingProvider
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter

    @State private var journalRouter = AppRouter()
    @State private var askMiraRouter = AppRouter()
    @State private var insightsRouter = AppRouter()
    @State private var selectedTab: AppTab = .journal
    @State private var isTabBarVisible: Bool = true

    // Feature states are hoisted to the root so streaming chat answers,
    // reflection generation, and live observers keep running when the
    // user switches tabs. Owning them per-tab-view used to let
    // `tabContent`'s switch destroy them mid-flight.
    @State private var askMiraState: AskMiraState?
    @State private var insightsState: InsightsListState?

    enum AppTab: Hashable { case journal, askMira, insights, settings }

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onPreferenceChange(TabBarVisibilityPreferenceKey.self) { visible in
                    guard visible != isTabBarVisible else { return }
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                        isTabBarVisible = visible
                    }
                }

            tabBar
                .offset(y: isTabBarVisible ? 15 : 160)
                .opacity(isTabBarVisible ? 1 : 0)
                .allowsHitTesting(isTabBarVisible)
                .animation(.spring(response: 0.48, dampingFraction: 0.88), value: isTabBarVisible)
                .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onOpenURL(perform: handleDeepLink)
        .task {
            ensureFeatureStates()
            // Kick the chat / insight observers once. Both methods are
            // idempotent — they no-op if their internal observation
            // task is already running — so re-entering this `.task` on
            // future RootView reappears doesn't double-subscribe.
            await askMiraState?.observe()
            await insightsState?.observe()
        }
    }

    private func ensureFeatureStates() {
        if askMiraState == nil {
            askMiraState = AskMiraState(
                repository: askMiraRepository,
                aiProvider: aiProvider,
                subscriptionService: subscriptionService,
                embeddingProvider: embeddingProvider,
                entryRepository: entryRepository,
                analyticsService: analyticsService
            )
        }
        if insightsState == nil {
            insightsState = InsightsListState(
                repository: insightRepository,
                entryRepository: entryRepository,
                aiProvider: aiProvider,
                subscriptionService: subscriptionService,
                analyticsService: analyticsService,
                crashReporter: crashReporter
            )
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        MiraTabBar(
            selection: Binding(
                get: { selectedTab },
                set: { newValue in handleTabSelection(newValue) }
            ),
            items: [
                .init(value: .journal,  title: "Journal",  systemImage: "book"),
                .init(value: .askMira,  title: "Ask",      systemImage: "sparkles"),
                .init(value: .insights, title: "Insights", systemImage: "quote.bubble"),
                .init(value: .settings, title: "Settings", systemImage: "gearshape"),
            ],
            tint: MiraPalette.tintColor(for: appearanceState.settings)
        )
        .padding(.bottom, 6)
    }

    /// Tapping the active tab while its stack is non-empty pops to root
    /// (matches native TabView behaviour).
    private func handleTabSelection(_ newValue: AppTab) {
        if newValue == selectedTab {
            router(for: newValue)?.popToRoot()
        } else {
            selectedTab = newValue
        }
    }

    private func router(for tab: AppTab) -> AppRouter? {
        switch tab {
        case .journal:  return journalRouter
        case .askMira:  return askMiraRouter
        case .insights: return insightsRouter
        case .settings: return nil
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .journal:  journalTab
        case .askMira:  askMiraTab
        case .insights: insightsTab
        case .settings: settingsTab
        }
    }

    private var journalTab: some View {
        NavigationStack(path: $journalRouter.path) {
            EntryListView(
                onCreateNew: { journalRouter.openEditor(.new) },
                onSelectEntry: { id in journalRouter.openDetail(id) }
            )
            .safeAreaPadding(.bottom, MiraTabBarLayout.reservedHeight)
            .ignoresSafeArea(.keyboard)
            .navigationDestination(for: AppRouter.Route.self) { route in
                routeView(route, router: journalRouter)
            }
        }
    }

    private var askMiraTab: some View {
        NavigationStack(path: $askMiraRouter.path) {
            Group {
                if let askMiraState {
                    AskMiraView(
                        state: askMiraState,
                        onSelectEntry: { id in askMiraRouter.openDetail(id) }
                    )
                } else {
                    AmbientBackground(moodLevels: [2, 4], intensity: 0.55)
                }
            }
            .navigationDestination(for: AppRouter.Route.self) { route in
                routeView(route, router: askMiraRouter)
            }
        }
    }

    private var insightsTab: some View {
        NavigationStack(path: $insightsRouter.path) {
            Group {
                if let insightsState {
                    InsightsListView(
                        state: insightsState,
                        onSelectInsight: { id in insightsRouter.openInsight(id) },
                        onOpenStats: { insightsRouter.openStats() }
                    )
                } else {
                    AmbientBackground(moodLevels: [3], intensity: 0.7)
                }
            }
            .safeAreaPadding(.bottom, MiraTabBarLayout.reservedHeight)
            .ignoresSafeArea(.keyboard)
            .navigationDestination(for: AppRouter.Route.self) { route in
                routeView(route, router: insightsRouter)
            }
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            SettingsView()
                .safeAreaPadding(.bottom, MiraTabBarLayout.reservedHeight)
                .ignoresSafeArea(.keyboard)
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRouter.Route, router: AppRouter) -> some View {
        switch route {
        case .detail(let id):
            EntryDetailView(
                entryID: id,
                onDismiss: { router.popToRoot() }
            )
        case .editor(.new):
            EntryEditorView(mode: .new)
        case .editor(.edit(let id)):
            EditorRouteView(entryID: id)
        case .dayList(let day):
            EntryListView(
                initialQuery: dayQuery(for: day),
                onCreateNew: { router.openEditor(.new) },
                onSelectEntry: { id in router.openDetail(id) }
            )
        case .insight(let id):
            InsightDetailView(
                insightID: id,
                onSelectEntry: { entryID in router.openDetail(entryID) }
            )
        case .stats:
            StatsView()
        }
    }

    private func dayQuery(for day: Date) -> EntryQuery {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? day
        var query = EntryQuery.all
        query.dateRange = start...end
        return query
    }

    /// Routes mira://… URLs into the journal tab. `mira://new` opens a
    /// fresh editor; future hosts (e.g. mira://entry/<uuid>) can extend
    /// the switch without touching the rest of the view hierarchy.
    @Environment(\.paywallPresenter) private var paywallPresenter

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mira" else { return }
        switch url.host {
        case "new":
            selectedTab = .journal
            journalRouter.popToRoot()
            journalRouter.openEditor(.new)
        case "paywall":
            // Lock-screen / Pro widgets call this when a free user
            // taps a locked tile — surface the paywall with the
            // .extraWidgets context so the headline matches.
            paywallPresenter.present(.feature(.extraWidgets))
        default:
            break
        }
    }
}

#Preview {
    RootView()
        .environment(\.entryRepository, UnimplementedEntryRepository())
        .environment(\.insightRepository, UnimplementedInsightRepository())
        .environment(\.aiProvider, UnimplementedAIProvider())
        .environment(\.embeddingProvider, UnimplementedEmbeddingProvider())
        .environment(\.photoStoring, UnimplementedPhotoStoring())
        .environment(\.subscriptionService, UnimplementedSubscriptionService())
        .environment(\.paywallPresenter, UnimplementedPaywallPresenter())
}
