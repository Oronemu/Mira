import Foundation
import Observation
import CoreKit

@MainActor
@Observable
public final class EntryDetailState {
    public private(set) var snapshot: EntrySnapshot?
    public private(set) var isLoading: Bool = true
    public private(set) var errorMessage: String?

    private let entryID: UUID
    private let repository: any EntryRepository

    public init(entryID: UUID, repository: any EntryRepository) {
        self.entryID = entryID
        self.repository = repository
    }

    public func observe() async {
        for await snapshot in repository.observe(query: .all) {
            self.snapshot = snapshot.first(where: { $0.id == entryID })
            isLoading = false
            if self.snapshot == nil {
                errorMessage = String(localized: "Entry was deleted.")
            }
        }
    }
}
