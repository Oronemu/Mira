import SwiftUI
import CoreKit
import DesignSystem

/// Modal sheet for creating or editing a single habit. The cadence
/// picker grows a target stepper for weekly/monthly choices; daily
/// hides it because the implicit target is "once per day".
struct HabitEditorView: View {
    let habit: Habit?
    let onSave: (Habit) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var tag: String = ""
    @State private var cadenceKind: CadenceKind = .daily
    @State private var target: Int = 3

    private enum CadenceKind: String, CaseIterable, Identifiable {
        case daily, weekly, monthly
        var id: String { rawValue }
    }

    private var isEditing: Bool { habit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(String(localized: "Name"))) {
                    TextField(String(localized: "e.g. Daily reflection"), text: $name)
                        .textInputAutocapitalization(.sentences)
                }
                Section(
                    header: Text(String(localized: "Tag")),
                    footer: Text(String(localized: "Mira counts entries that carry this tag toward the habit."))
                ) {
                    TextField(String(localized: "e.g. meditation"), text: $tag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section(header: Text(String(localized: "Cadence"))) {
                    Picker(String(localized: "Cadence"), selection: $cadenceKind) {
                        Text(String(localized: "Daily")).tag(CadenceKind.daily)
                        Text(String(localized: "Weekly")).tag(CadenceKind.weekly)
                        Text(String(localized: "Monthly")).tag(CadenceKind.monthly)
                    }
                    .pickerStyle(.segmented)

                    if cadenceKind != .daily {
                        Stepper(
                            value: $target,
                            in: 1...30,
                            step: 1
                        ) {
                            Text(String(format: String(localized: "%lld times %@"),
                                       target,
                                       cadenceKind == .weekly
                                            ? String(localized: "per week")
                                            : String(localized: "per month")))
                        }
                    }
                }
                if isEditing {
                    Section {
                        Button(role: .destructive, action: onDelete) {
                            Text(String(localized: "Delete habit"))
                        }
                    }
                }
            }
            .navigationTitle(isEditing
                ? String(localized: "Edit habit")
                : String(localized: "New habit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = trimmedName.isEmpty
                            ? String(localized: "Untitled habit")
                            : trimmedName
                        let cadence: Habit.Cadence
                        switch cadenceKind {
                        case .daily:   cadence = .daily
                        case .weekly:  cadence = .weekly(target: target)
                        case .monthly: cadence = .monthly(target: target)
                        }
                        let updated = Habit(
                            id: habit?.id ?? UUID(),
                            name: finalName,
                            tag: tag,
                            cadence: cadence,
                            createdAt: habit?.createdAt ?? .now
                        )
                        onSave(updated)
                    }
                    .disabled(tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let habit, name.isEmpty && tag.isEmpty {
                    name = habit.name
                    tag = habit.tag
                    switch habit.cadence {
                    case .daily:
                        cadenceKind = .daily
                    case .weekly(let t):
                        cadenceKind = .weekly
                        target = t
                    case .monthly(let t):
                        cadenceKind = .monthly
                        target = t
                    }
                }
            }
        }
    }
}
