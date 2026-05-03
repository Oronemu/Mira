import SwiftUI
import CoreKit
import DesignSystem

/// Modal sheet for creating or editing a single persona. Editing mode
/// receives the persona to mutate; create mode passes nil and lands a
/// fresh `AskMiraPersona` on save. The built-in default never reaches
/// this view — list code routes around it.
struct PersonaEditorView: View {
    let persona: AskMiraPersona?
    let onSave: (AskMiraPersona) -> Void
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var prompt: String = ""

    private var isEditing: Bool { persona != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(String(localized: "Name"))) {
                    TextField(String(localized: "e.g. Stoic coach"), text: $name)
                        .textInputAutocapitalization(.sentences)
                }

                Section(
                    header: Text(String(localized: "System prompt")),
                    footer: Text(String(localized: "Examples: \"Use short, direct sentences\", \"Ask a Socratic question back\", \"Always end with a small actionable nudge\"."))
                ) {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 160)
                        .font(.system(.body, design: .serif))
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Text(String(localized: "Delete persona"))
                        }
                    }
                }
            }
            .navigationTitle(isEditing
                ? String(localized: "Edit persona")
                : String(localized: "New persona"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { onDelete() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = trimmed.isEmpty
                            ? String(localized: "Untitled persona")
                            : trimmed
                        let updated = AskMiraPersona(
                            id: persona?.id ?? UUID(),
                            name: finalName,
                            systemPrompt: prompt,
                            createdAt: persona?.createdAt ?? .now,
                            isBuiltIn: false
                        )
                        onSave(updated)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              && prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let persona, name.isEmpty && prompt.isEmpty {
                    name = persona.name
                    prompt = persona.systemPrompt
                }
            }
        }
    }
}
