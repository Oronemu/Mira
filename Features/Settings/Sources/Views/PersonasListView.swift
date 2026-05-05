import SwiftUI
import CoreKit
import DesignSystem
import Utilities

/// Manages user-authored Ask Mira personas. The built-in "Default"
/// persona always sits at the top and is non-destructible — it's the
/// fall-back voice when no custom persona is selected.
public struct PersonasListView: View {
    @State private var personas: [AskMiraPersona] = []
    @State private var activeID: UUID? = nil
    @State private var editing: AskMiraPersona?
    @State private var creating = false

    private let store = AskMiraPersonaStore()

    public init() {}

    public var body: some View {
        ZStack {
            AmbientBackground(moodLevels: [3], intensity: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsHero(
                        title: "Personas",
                        subtitle: "How Mira sounds when she answers"
                    )

                    VStack(spacing: 10) {
                        ForEach(personas) { persona in
                            personaRow(persona)
                        }
                    }

                    addButton

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
        .collapsibleHeroTitle("Personas")
        .task { reload() }
        .sheet(item: $editing) { persona in
            PersonaEditorView(persona: persona) { updated in
                save(updated)
                editing = nil
            } onDelete: {
                delete(persona)
                editing = nil
            }
        }
        .sheet(isPresented: $creating) {
            PersonaEditorView(persona: nil) { created in
                save(created)
                creating = false
            } onDelete: {
                creating = false
            }
        }
    }

    // MARK: - Rows

    private func personaRow(_ persona: AskMiraPersona) -> some View {
        Button {
            if !persona.isBuiltIn {
                editing = persona
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    activate(persona)
                } label: {
                    Image(systemName: persona.id == activeID ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(persona.id == activeID ? Color.accentColor : MiraPalette.secondaryText)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    personaName(persona)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(MiraPalette.primaryText)
                    Text(preview(for: persona))
                        .font(MiraTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if !persona.isBuiltIn {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MiraPalette.secondaryText.opacity(0.7))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Built-in personas store their name as the literal English key
    /// ("Default") so the model layer stays language-agnostic. The view
    /// routes that name back through Localizable.xcstrings so it shows
    /// up translated in non-English locales. User-authored names are
    /// rendered verbatim — we don't want a persona called "Save" to
    /// silently translate.
    private func personaName(_ persona: AskMiraPersona) -> Text {
        if persona.isBuiltIn {
            return Text(LocalizedStringKey(persona.name))
        }
        return Text(persona.name)
    }

    private func preview(for persona: AskMiraPersona) -> LocalizedStringKey {
        if persona.isBuiltIn {
            return "Mira's default warm, grounded voice."
        }
        let trimmed = persona.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return LocalizedStringKey(trimmed.isEmpty ? "—" : trimmed)
    }

    private var addButton: some View {
        Button { creating = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text(String(localized: "New persona"))
            }
            .font(MiraTypography.body.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var footnote: some View {
        Text("Personas only change Mira's tone. Citation rules and the journal-grounded behavior stay on regardless.")
            .font(MiraTypography.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Actions

    private func reload() {
        personas = store.load()
        activeID = store.active().id
    }

    private func activate(_ persona: AskMiraPersona) {
        store.setActiveID(persona.id)
        activeID = persona.id
    }

    private func save(_ persona: AskMiraPersona) {
        var current = personas
        if let index = current.firstIndex(where: { $0.id == persona.id }) {
            current[index] = persona
        } else {
            current.append(persona)
        }
        store.saveUserPersonas(current)
        reload()
    }

    private func delete(_ persona: AskMiraPersona) {
        guard !persona.isBuiltIn else { return }
        let remaining = personas.filter { $0.id != persona.id }
        store.saveUserPersonas(remaining)
        if activeID == persona.id {
            store.setActiveID(nil)
        }
        reload()
    }
}
