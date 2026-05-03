import SwiftUI
import CoreKit
import DesignSystem

/// Modal sheet for creating or editing a single goal. Deadline is
/// optional — toggling the switch reveals the date picker.
struct GoalEditorView: View {
    let goal: Goal?
    let onSave: (Goal) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var tag: String = ""
    @State private var targetCount: Int = 30
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = .now.addingTimeInterval(60 * 60 * 24 * 30.0)

    private var isEditing: Bool { goal != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(String(localized: "Name"))) {
                    TextField(String(localized: "e.g. 100 entries this year"), text: $name)
                        .textInputAutocapitalization(.sentences)
                }
                Section(
                    header: Text(String(localized: "Tag")),
                    footer: Text(String(localized: "Mira counts entries with this tag toward the goal."))
                ) {
                    TextField(String(localized: "e.g. journal"), text: $tag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section(header: Text(String(localized: "Target"))) {
                    Stepper(value: $targetCount, in: 1...10000, step: 1) {
                        Text(String(format: String(localized: "%lld entries"), targetCount))
                    }
                }
                Section(header: Text(String(localized: "Deadline"))) {
                    Toggle(String(localized: "Has deadline"), isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker(
                            String(localized: "By"),
                            selection: $deadline,
                            displayedComponents: .date
                        )
                    }
                }
                if isEditing {
                    Section {
                        Button(role: .destructive, action: onDelete) {
                            Text(String(localized: "Delete goal"))
                        }
                    }
                }
            }
            .navigationTitle(isEditing
                ? String(localized: "Edit goal")
                : String(localized: "New goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = trimmedName.isEmpty
                            ? String(localized: "Untitled goal")
                            : trimmedName
                        let updated = Goal(
                            id: goal?.id ?? UUID(),
                            name: finalName,
                            tag: tag,
                            targetCount: targetCount,
                            deadline: hasDeadline ? deadline : nil,
                            createdAt: goal?.createdAt ?? .now
                        )
                        onSave(updated)
                    }
                    .disabled(tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let goal, name.isEmpty && tag.isEmpty {
                    name = goal.name
                    tag = goal.tag
                    targetCount = goal.targetCount
                    hasDeadline = goal.deadline != nil
                    if let d = goal.deadline { deadline = d }
                }
            }
        }
    }
}
