import Foundation

/// User-authored Ask Mira voice. The system prompt acts as a *style*
/// layer on top of the built-in grounding rules — it cannot disable
/// the journal-citation requirement or the "don't invent facts" rule
/// because those live in `PromptTemplates.askSystem(language:)` and
/// always ship first. Personas append after.
///
/// Pro feature gated by `ProEntitlement.customAIPersonas`. Free users
/// always run with the implicit default voice.
public struct AskMiraPersona: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var systemPrompt: String
    public let createdAt: Date
    /// `true` for the synthetic "Default" persona surfaced by the
    /// store when no user-authored personas exist; the UI hides
    /// destructive actions on it so the list always has something to
    /// fall back to.
    public let isBuiltIn: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        systemPrompt: String,
        createdAt: Date = .now,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.createdAt = createdAt
        self.isBuiltIn = isBuiltIn
    }
}

public extension AskMiraPersona {
    /// Synthetic default. Stored at a stable UUID so it survives JSON
    /// roundtrips and the active-id pointer keeps resolving.
    static let defaultID = UUID(uuidString: "00000000-0000-0000-0000-00000000D00D")!

    static let `default` = AskMiraPersona(
        id: defaultID,
        name: "Default",
        systemPrompt: "",
        createdAt: Date(timeIntervalSince1970: 0),
        isBuiltIn: true
    )
}
