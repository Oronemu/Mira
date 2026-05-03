import SwiftUI
import CoreKit
import DesignSystem

public struct EntryFilterView: View {
    @Environment(\.dismiss) private var dismiss

    private let initialQuery: EntryQuery
    private let availableTags: [String]
    private let onApply: (EntryQuery) -> Void
    private let canSaveAsFilter: Bool
    private let onSave: (String) -> Void
    private let onSavePaywallTrigger: () -> Void

    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var dateActive: Bool
    @State private var moods: Set<Mood>
    @State private var selectedTags: Set<String>
    @State private var showingSavePrompt = false
    @State private var saveName: String = ""

    public init(
        initialQuery: EntryQuery,
        availableTags: [String] = [],
        canSaveAsFilter: Bool = false,
        onApply: @escaping (EntryQuery) -> Void,
        onSave: @escaping (String) -> Void = { _ in },
        onSavePaywallTrigger: @escaping () -> Void = {}
    ) {
        self.initialQuery = initialQuery
        self.availableTags = availableTags
        self.canSaveAsFilter = canSaveAsFilter
        self.onApply = onApply
        self.onSave = onSave
        self.onSavePaywallTrigger = onSavePaywallTrigger

        let cal = Calendar.current
        let now = Date.now
        let defaultFrom = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) ?? now

        if let range = initialQuery.dateRange {
            _fromDate = State(initialValue: range.lowerBound)
            _toDate = State(initialValue: range.upperBound)
            _dateActive = State(initialValue: true)
        } else {
            _fromDate = State(initialValue: defaultFrom)
            _toDate = State(initialValue: now)
            _dateActive = State(initialValue: false)
        }
        _moods = State(initialValue: initialQuery.moods ?? [])
        _selectedTags = State(initialValue: Set((initialQuery.tags ?? []).map { $0.lowercased() }))
    }

    public var body: some View {
        NavigationStack {
            MiraSheetChrome(moodLevels: moods.map(\.rawValue)) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        dateCard
                        moodCard
                        tagsCard
                        if hasAnyDraftFilter {
                            saveAsFilterButton
                        }
                        resetButton
                        Color.clear.frame(height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                        .fontWeight(.semibold)
                }
            }
            .hideTabBar()
            .alert(
                String(localized: "Name this filter"),
                isPresented: $showingSavePrompt
            ) {
                TextField(String(localized: "e.g. Bad weeks"), text: $saveName)
                Button(String(localized: "Save")) {
                    let trimmed = saveName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let final = trimmed.isEmpty ? String(localized: "Untitled filter") : trimmed
                    apply()  // commit current filter to the list first
                    onSave(final)
                    saveName = ""
                    dismiss()
                }
                Button(String(localized: "Cancel"), role: .cancel) { saveName = "" }
            }
        }
        .miraSheet([.large])
    }

    @ViewBuilder
    private var saveAsFilterButton: some View {
        Button {
            if canSaveAsFilter {
                showingSavePrompt = true
            } else {
                onSavePaywallTrigger()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: canSaveAsFilter ? "bookmark" : "lock.fill")
                Text(String(localized: "Save as smart filter"))
                    .font(MiraTypography.body.weight(.semibold))
                if !canSaveAsFilter {
                    ProBadge()
                }
            }
            .foregroundStyle(.tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(.tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date

    private var dateCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Date range").eyebrowStyle()
                    Spacer()
                    if dateActive {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                dateActive = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(MiraPalette.secondaryText)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Clear date filter"))
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    DatePicker(
                        "From",
                        selection: $fromDate,
                        in: ...toDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "To",
                        selection: $toDate,
                        in: fromDate...,
                        displayedComponents: .date
                    )
                }
                .font(MiraTypography.body)
                .opacity(dateActive ? 1 : 0.55)
                .onChange(of: fromDate) { _, _ in markDateActive() }
                .onChange(of: toDate) { _, _ in markDateActive() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func markDateActive() {
        guard !dateActive else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            dateActive = true
        }
    }

    // MARK: - Mood

    private var moodCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Mood").eyebrowStyle()
                HStack(spacing: 10) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        moodDot(mood)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func moodDot(_ mood: Mood) -> some View {
        let isSelected = moods.contains(mood)
        let color = MiraPalette.mood(level: mood.rawValue)
        return Button {
            if isSelected { moods.remove(mood) } else { moods.insert(mood) }
        } label: {
            ZStack {
                Circle()
                    .fill(color.opacity(0.45))
                    .frame(width: 58, height: 58)
                    .blur(radius: 14)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.75)

                Circle()
                    .fill(color.opacity(isSelected ? 0.22 : 0))
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(MiraPalette.secondaryBackground)
                    .frame(width: 44, height: 44)
                    .opacity(isSelected ? 0 : 1)

                Circle()
                    .strokeBorder(isSelected ? color : MiraPalette.divider, lineWidth: isSelected ? 1.5 : 1)
                    .frame(width: 44, height: 44)

                Text(mood.emoji)
                    .font(.system(size: 22))
            }
            .frame(width: 58, height: 58)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(mood.label))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
    }

    // MARK: - Tags

    private var tagsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Tags").eyebrowStyle()
                    Spacer()
                    if !selectedTags.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedTags.removeAll()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(MiraPalette.secondaryText)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Clear tag filter"))
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if availableTags.isEmpty {
                    Text("No tags yet — add tags to entries to filter by them.")
                        .font(.system(size: 13))
                        .foregroundStyle(MiraPalette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(availableTags, id: \.self) { tag in
                            tagChip(tag)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tagChip(_ tag: String) -> some View {
        let isSelected = selectedTags.contains(tag)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                if isSelected {
                    selectedTags.remove(tag)
                } else {
                    selectedTags.insert(tag)
                }
            }
        } label: {
            Text(tag)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? MiraPalette.primaryText : MiraPalette.primaryText.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(isSelected
                                   ? MiraPalette.mood(level: 4).opacity(0.4)
                                   : MiraPalette.secondaryBackground.opacity(0.6))
                }
                .overlay {
                    Capsule().strokeBorder(
                        isSelected
                            ? MiraPalette.primaryText.opacity(0.5)
                            : MiraPalette.primaryText.opacity(0.08),
                        lineWidth: 1
                    )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tag))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                dateActive = false
                moods.removeAll()
                selectedTags.removeAll()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset filters")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(MiraPalette.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                Capsule(style: .continuous)
                    .fill(MiraPalette.glassTint)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(MiraPalette.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!hasAnyDraftFilter)
        .opacity(hasAnyDraftFilter ? 1 : 0.5)
    }

    private var hasAnyDraftFilter: Bool {
        dateActive || !moods.isEmpty || !selectedTags.isEmpty
    }

    // MARK: - Apply

    private func apply() {
        var next = initialQuery

        if dateActive {
            let cal = Calendar.current
            let start = cal.startOfDay(for: fromDate)
            let endStart = cal.startOfDay(for: toDate)
            let end = cal.date(byAdding: DateComponents(day: 1, second: -1), to: endStart) ?? toDate
            next.dateRange = start <= end ? start...end : nil
        } else {
            next.dateRange = nil
        }

        next.moods = moods.isEmpty ? nil : moods

        next.tags = selectedTags.isEmpty ? nil : Array(selectedTags).sorted()

        onApply(next)
        dismiss()
    }
}
