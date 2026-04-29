import Foundation
import SwiftData

@Model
public final class AskMiraTurn {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var question: String
    public var answer: String
    public var referencedEntryIDs: [UUID]

    /// Back-reference to the owning chat. Optional so SwiftData can
    /// perform a lightweight migration for users who upgraded from the
    /// pre-chat schema; orphaned turns are adopted into per-day legacy
    /// chats on first launch (see `SwiftDataAskMiraRepository`).
    public var chat: AskMiraChat?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        question: String,
        answer: String,
        referencedEntryIDs: [UUID] = [],
        chat: AskMiraChat? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.question = question
        self.answer = answer
        self.referencedEntryIDs = referencedEntryIDs
        self.chat = chat
    }
}
