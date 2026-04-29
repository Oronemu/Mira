import Foundation

/// One round-trip with the journal: the user's question, the generated
/// answer, and the entries the model grounded its answer in.
public struct AskMiraTurnSnapshot: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let question: String
    public let answer: String
    public let referencedEntryIDs: [UUID]

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        question: String,
        answer: String,
        referencedEntryIDs: [UUID] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.question = question
        self.answer = answer
        self.referencedEntryIDs = referencedEntryIDs
    }
}
