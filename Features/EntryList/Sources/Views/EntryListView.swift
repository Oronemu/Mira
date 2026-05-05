import SwiftUI
import CoreKit
import DesignSystem
import Utilities

public struct EntryListView: View {
    @Environment(\.entryRepository) private var repository
    @Environment(\.analyticsService) private var analyticsService
    @Environment(\.crashReporter) private var crashReporter
    @Environment(\.subscriptionService) private var subscriptionService
    @Environment(\.paywallPresenter) private var paywallPresenter

    /// State owned by this view when no parent injects one. The journal
    /// tab passes a hoisted state in (so it survives tab switches and
    /// doesn't flash a loader on every reselect); the dayList sub-route
    /// leaves it nil and we create one scoped to the pushed view.
    @State private var ownedState: EntryListState?
    @State private var searchText: String = ""
    @State private var pendingDeletionID: UUID?
    @State private var showFilters = false
    @State private var visibleSectionID: String?
    @State private var showBulkDeleteConfirm = false
    @State private var status: SubscriptionStatus = .unknown
    @State private var savedFilters: [SavedFilter] = []
    @State private var activeFilterID: UUID? = nil
    @Namespace private var rowNamespace

    private let savedFilterStore = SavedFilterStore()

    private let injectedState: EntryListState?
    private let initialQuery: EntryQuery
    private let onCreateNew: () -> Void
    private let onSelectEntry: (UUID) -> Void

    public init(
        state: EntryListState? = nil,
        initialQuery: EntryQuery = .all,
        onCreateNew: @escaping () -> Void = {},
        onSelectEntry: @escaping (UUID) -> Void = { _ in }
    ) {
        self.injectedState = state
        self.initialQuery = initialQuery
        self.onCreateNew = onCreateNew
        self.onSelectEntry = onSelectEntry
    }

    private var state: EntryListState? {
        injectedState ?? ownedState
    }

    /// Stable identity of whichever state we're currently using. Lets the
    /// observe-task re-fire if the injected state arrives *after* the view
    /// already created an ownedState (RootView wires `entryListState`
    /// asynchronously in its own .task — the swap from owned to injected
    /// otherwise leaves the new state un-observed and the loader spinning).
    private var stateIdentity: ObjectIdentifier? {
        state.map(ObjectIdentifier.init)
    }

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: ambientMoodLevels)

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
        .toolbar { toolbarContent }
        .collapsibleHeroTitle(Text("Journal"), subtitle: journalSubtitleText)
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search entries")
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            state?.updateSearchText(searchText)
        }
        .task(id: stateIdentity) {
            if injectedState == nil, ownedState == nil {
                ownedState = EntryListState(
                    repository: repository,
                    initialQuery: initialQuery,
                    analyticsService: analyticsService,
                    crashReporter: crashReporter
                )
            }
            await state?.observe()
        }
        .task {
            // Saved filters are Pro — keep status fresh so the strip
            // appears the moment a purchase completes and disappears
            // again on cancel without requiring a screen reopen.
            savedFilters = savedFilterStore.load()
            status = await subscriptionService.status
            for await snapshot in subscriptionService.statusUpdates {
                status = snapshot
            }
        }
        .sheet(isPresented: $showFilters) {
            if let state {
                EntryFilterView(
                    initialQuery: state.query,
                    availableTags: state.availableTags,
                    canSaveAsFilter: status.isPro,
                    onApply: { newQuery in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            state.query = newQuery
                        }
                        // Manual edits invalidate any "active saved
                        // filter" highlight; the user's now driving.
                        activeFilterID = nil
                    },
                    onSave: { name in
                        let filter = SavedFilter(name: name, from: state.query)
                        savedFilterStore.save(filter)
                        savedFilters = savedFilterStore.load()
                        activeFilterID = filter.id
                        analyticsService.log(
                            event: "smart_filter_saved",
                            parameters: ["filter_count": .int(savedFilters.count)]
                        )
                    },
                    onSavePaywallTrigger: {
                        // iOS won't stack a fresh root sheet on top of the
                        // open filter sheet — close the filter first, then
                        // raise the paywall after the dismiss animation.
                        showFilters = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(280))
                            paywallPresenter.present(.feature(.smartFilters))
                        }
                    }
                )
            }
        }
        .alert(
            bulkDeleteTitle,
            isPresented: $showBulkDeleteConfirm
        ) {
            Button("Delete", role: .destructive) {
                if let state {
                    Task { await state.deleteSelected() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private var bulkDeleteTitle: LocalizedStringKey {
        let count = state?.selectionCount ?? 0
        return count > 1 ? "Delete selected entries?" : "Delete entry?"
    }

    private var journalSubtitleText: Text {
        let total = state?.sections.reduce(0) { $0 + $1.entries.count } ?? 0
        let month = Date.now.formatted(.dateTime.month(.wide).year())
        return Text("\(total) entries · \(month)")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let state, state.isSelectionMode {
            selectionToolbar(state: state)
        } else {
            normalToolbar
        }
    }

    @ToolbarContentBuilder
    private var normalToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showFilters = true
            } label: {
                Image(systemName: state?.hasActiveFilters == true
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(MiraPalette.primaryText)
            }
            .accessibilityLabel("Filters")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                onCreateNew()
            } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(MiraPalette.primaryText)
            }
            .accessibilityLabel("New entry")
        }
    }

    @ToolbarContentBuilder
    private func selectionToolbar(state: EntryListState) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                state.exitSelection()
            } label: {
                Text("Cancel").foregroundStyle(MiraPalette.primaryText)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if state.allVisibleSelected {
                    state.deselectAll()
                } else {
                    state.selectAllVisible()
                }
            } label: {
                Text(state.allVisibleSelected ? "Deselect All" : "Select All")
                    .foregroundStyle(MiraPalette.primaryText)
            }
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showBulkDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(state.selectionCount > 0 ? Color.red : MiraPalette.secondaryText.opacity(0.5))
            }
            .disabled(state.selectionCount == 0)
            .accessibilityLabel("Delete selected")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(state: EntryListState) -> some View {
        VStack(spacing: 0) {
            if status.isPro && !savedFilters.isEmpty {
                SavedFiltersStripView(
                    filters: savedFilters,
                    activeFilterID: activeFilterID,
                    isUnfiltered: !state.hasActiveFilters,
                    onApply: { filter in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            state.query = filter.makeQuery(text: state.query.text)
                        }
                        activeFilterID = filter.id
                    },
                    onClear: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            state.query = EntryQuery(text: state.query.text)
                        }
                        activeFilterID = nil
                    },
                    onDelete: { filter in
                        savedFilterStore.delete(id: filter.id)
                        savedFilters = savedFilterStore.load()
                        if activeFilterID == filter.id {
                            activeFilterID = nil
                        }
                    }
                )
            }

            innerContent(state: state)
        }
    }

    @ViewBuilder
    private func innerContent(state: EntryListState) -> some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.sections.isEmpty {
            if state.query.text != nil || state.hasActiveFilters {
                emptyContainer(title: "No matches", subtitle: "Adjust filters or clear the search.")
            } else {
                // On a fresh install with iCloud sync on, this view renders
                // before the first pull completes. Swap the "No entries yet"
                // copy for a live indicator so the screen doesn't falsely
                // claim the journal is empty while records are still
                // streaming down.
                FreshInstallEmptyState()
            }
        } else {
            entriesScroll(state: state)
        }
    }

    private func entriesScroll(state: EntryListState) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                hero(state: state)

                ForEach(Array(state.sections.enumerated()), id: \.element.id) { index, section in
                    monthSection(section, isFirst: index == 0, state: state)
                        .id(section.id)
                }

                Color.clear.frame(height: 32)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .animation(.spring(duration: 0.45, bounce: 0.1), value: state.sections.map(\.id))
            .animation(.spring(duration: 0.35, bounce: 0.15),
                       value: state.sections.flatMap { $0.entries.map(\.id) })
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleSectionID, anchor: .top)
    }

    // MARK: - Hero

    private func hero(state: EntryListState) -> some View {
        let total = state.sections.reduce(0) { $0 + $1.entries.count }
        let month = Date.now.formatted(.dateTime.month(.wide).year())
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Journal")
                    .font(MiraTypography.hero)
                    .foregroundStyle(MiraPalette.primaryText)
                SyncStatusIndicator()
            }
            Text("\(total) entries · \(month)")
                .eyebrowStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Month section

    private func monthSection(
        _ section: EntryMonthSection,
        isFirst: Bool,
        state: EntryListState
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            monthHeader(section)
                .padding(.top, isFirst ? 0 : 8)

            ForEach(section.entries) { entry in
                Button {
                    if state.isSelectionMode {
                        state.toggle(id: entry.id)
                    } else {
                        onSelectEntry(entry.id)
                    }
                } label: {
                    EntryRowCard(
                        entry: entry,
                        namespace: rowNamespace,
                        isSelectionMode: state.isSelectionMode,
                        isSelected: state.selection.contains(entry.id)
                    )
                }
                .buttonStyle(PressableCardStyle())
                .contextMenu {
                    if !state.isSelectionMode {
                        Button {
                            state.enterSelection(with: entry.id)
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                    }
                    Button(role: .destructive) {
                        pendingDeletionID = entry.id
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .alert(
                    "Delete this entry?",
                    isPresented: deletionPresented
                ) {
                    Button("Delete", role: .destructive) {
                        if let id = pendingDeletionID {
                            Task { await state.delete(id: id) }
                        }
                        pendingDeletionID = nil
                    }
                    Button("Cancel", role: .cancel) {
                        pendingDeletionID = nil
                    }
                } message: {
                    Text("This can't be undone.")
                }
            }
        }
    }

    private func monthHeader(_ section: EntryMonthSection) -> some View {
        let parts = section.title.split(separator: " ", maxSplits: 1).map(String.init)
        let month = parts.first ?? section.title
        let year = parts.count > 1 ? parts[1] : ""
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(month)
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
            if !year.isEmpty {
                Text(year)
                    .eyebrowStyle()
            }
            Spacer()
            Text("\(section.entries.count)")
                .eyebrowStyle()
        }
    }

    // MARK: - Empty

    private func emptyContainer(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(MiraTypography.displayTitle)
                .foregroundStyle(MiraPalette.primaryText)
            Text(subtitle)
                .font(MiraTypography.body)
                .foregroundStyle(MiraPalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helpers

    private var deletionPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletionID != nil },
            set: { if !$0 { pendingDeletionID = nil } }
        )
    }

    /// Mood levels feeding the AmbientBackground. Prefers the currently
    /// visible month's moods so the screen's tone shifts as the user scrolls
    /// through different periods; falls back to the most recent entries.
    private var ambientMoodLevels: [Int] {
        guard let state else { return [] }
        if let id = visibleSectionID,
           let section = state.sections.first(where: { $0.id == id }) {
            return section.entries.compactMap { $0.mood?.rawValue }
        }
        return state.sections
            .flatMap(\.entries)
            .prefix(12)
            .compactMap { $0.mood?.rawValue }
    }

}

