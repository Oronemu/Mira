import SwiftUI
import CoreKit
import DesignSystem

public struct EntryFilterView: View {
    @Environment(\.dismiss) private var dismiss

    private let initialQuery: EntryQuery
    private let onApply: (EntryQuery) -> Void

    @State private var fromDate: Date
    @State private var toDate: Date
    @State private var dateActive: Bool
    @State private var moods: Set<Mood>
    @State private var tagsDraft: String

    public init(initialQuery: EntryQuery, onApply: @escaping (EntryQuery) -> Void) {
        self.initialQuery = initialQuery
        self.onApply = onApply

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
        _tagsDraft = State(initialValue: initialQuery.tags?.joined(separator: ", ") ?? "")
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(moodLevels: moods.map(\.rawValue), intensity: 0.55)

                ScrollView {
                    VStack(spacing: 20) {
                        dateCard
                        moodCard
                        tagsCard
                        resetButton
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 18)
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
        }
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
            VStack(alignment: .leading, spacing: 10) {
                Text("Tags").eyebrowStyle()
                TextField(text: $tagsDraft, prompt: Text("comma, separated")) {
                    Text("Tags")
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(MiraTypography.body)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MiraPalette.secondaryBackground.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                dateActive = false
                moods.removeAll()
                tagsDraft = ""
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
        dateActive || !moods.isEmpty || !tagsDraft.trimmingCharacters(in: .whitespaces).isEmpty
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

        let parsed = tagsDraft
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        next.tags = parsed.isEmpty ? nil : parsed

        onApply(next)
        dismiss()
    }
}
