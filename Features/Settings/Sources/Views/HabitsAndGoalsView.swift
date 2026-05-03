import SwiftUI
import CoreKit
import DesignSystem
import Utilities

/// Pro management screen for tag-driven habits and goals. Shows two
/// sections (habits with cadence-aware progress, goals with count
/// progress against optional deadline). Tap a row → editor; "+" in
/// each section header creates a new one. All progress is derived
/// live from `EntryRepository` — no parallel logging model.
public struct HabitsAndGoalsView: View {
    @Environment(\.entryRepository) private var entryRepository

    @State private var entries: [EntrySnapshot] = []
    @State private var habits: [Habit] = []
    @State private var goals: [Goal] = []
    @State private var editingHabit: HabitEditTarget?
    @State private var editingGoal: GoalEditTarget?

    private let habitStore = HabitStore()
    private let goalStore = GoalStore()

    private struct HabitEditTarget: Identifiable {
        let id: UUID
        let habit: Habit?
        var isNew: Bool { habit == nil }
    }
    private struct GoalEditTarget: Identifiable {
        let id: UUID
        let goal: Goal?
        var isNew: Bool { goal == nil }
    }

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3, 4], intensity: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsHero(
                        title: "Habits & goals",
                        subtitle: "Tag-driven targets, derived from your journal"
                    )

                    habitsSection

                    goalsSection

                    footnote

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .hideTabBar()
        .collapsibleHeroTitle("Habits & goals")
        .task { await reload() }
        .sheet(item: $editingHabit) { target in
            HabitEditorView(
                habit: target.habit,
                onSave: { habit in
                    habitStore.save(habit)
                    habits = habitStore.load()
                    editingHabit = nil
                },
                onCancel: { editingHabit = nil },
                onDelete: {
                    if let h = target.habit { habitStore.delete(id: h.id) }
                    habits = habitStore.load()
                    editingHabit = nil
                }
            )
        }
        .sheet(item: $editingGoal) { target in
            GoalEditorView(
                goal: target.goal,
                onSave: { goal in
                    goalStore.save(goal)
                    goals = goalStore.load()
                    editingGoal = nil
                },
                onCancel: { editingGoal = nil },
                onDelete: {
                    if let g = target.goal { goalStore.delete(id: g.id) }
                    goals = goalStore.load()
                    editingGoal = nil
                }
            )
        }
    }

    // MARK: - Sections

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Habits",
                onAdd: { editingHabit = HabitEditTarget(id: UUID(), habit: nil) }
            )
            if habits.isEmpty {
                emptyState(text: "Track tags you want to repeat — daily, weekly, or monthly.")
            } else {
                ForEach(habits) { habit in
                    habitRow(habit)
                }
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Goals",
                onAdd: { editingGoal = GoalEditTarget(id: UUID(), goal: nil) }
            )
            if goals.isEmpty {
                emptyState(text: "Pick a tag and a target — Mira will count them as you write.")
            } else {
                ForEach(goals) { goal in
                    goalRow(goal)
                }
            }
        }
    }

    private func sectionHeader(title: LocalizedStringKey, onAdd: @escaping () -> Void) -> some View {
        HStack {
            Text(title).eyebrowStyle()
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
    }

    private func emptyState(text: LocalizedStringKey) -> some View {
        Text(text)
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MiraPalette.secondaryBackground.opacity(0.4))
            )
    }

    // MARK: - Rows

    private func habitRow(_ habit: Habit) -> some View {
        let progress = HabitProgressCalculator.snapshot(for: habit, entries: entries)
        return Button {
            editingHabit = HabitEditTarget(id: habit.id, habit: habit)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(habit.name)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                    Spacer()
                    Text(progressLabel(progress))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text("#\(habit.tag)")
                        .font(MiraTypography.caption)
                        .foregroundStyle(.tint)
                    Text("·")
                        .font(MiraTypography.caption)
                        .foregroundStyle(.secondary)
                    Text(windowLabel(progress.windowLabel))
                        .font(MiraTypography.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func goalRow(_ goal: Goal) -> some View {
        let progress = GoalProgressCalculator.snapshot(for: goal, entries: entries)
        return Button {
            editingGoal = GoalEditTarget(id: goal.id, goal: goal)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(goal.name)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                    Spacer()
                    Text("\(progress.current) / \(progress.target)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(progress.isExpired ? .red : .secondary)
                }
                HStack(spacing: 6) {
                    Text("#\(goal.tag)")
                        .font(MiraTypography.caption)
                        .foregroundStyle(.tint)
                    if let deadline = goal.deadline {
                        Text("·")
                            .font(MiraTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(deadline, format: .dateTime.day().month().year())
                            .font(MiraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    if progress.isExpired {
                        Text(String(localized: "(expired)"))
                            .font(MiraTypography.caption)
                            .foregroundStyle(.red)
                    }
                }
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func windowLabel(_ window: HabitProgressCalculator.WindowLabel) -> String {
        switch window {
        case .today:     return String(localized: "Today")
        case .thisWeek:  return String(localized: "This week")
        case .thisMonth: return String(localized: "This month")
        }
    }

    private func progressLabel(_ snapshot: HabitProgressCalculator.Snapshot) -> String {
        snapshot.target == 1
            ? (snapshot.isComplete ? String(localized: "✓") : String(localized: "—"))
            : "\(snapshot.current) / \(snapshot.target)"
    }

    private var footnote: some View {
        Text(String(localized: "Progress is derived from your entries — just keep writing and tagging."))
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Loading

    private func reload() async {
        habits = habitStore.load()
        goals = goalStore.load()
        do {
            entries = try await entryRepository.fetch(matching: .all)
        } catch {
            entries = []
        }
    }
}
