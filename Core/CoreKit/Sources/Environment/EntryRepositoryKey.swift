import SwiftUI

private struct EntryRepositoryKey: EnvironmentKey {
    static let defaultValue: any EntryRepository = UnimplementedEntryRepository()
}

public extension EnvironmentValues {
    var entryRepository: any EntryRepository {
        get { self[EntryRepositoryKey.self] }
        set { self[EntryRepositoryKey.self] = newValue }
    }
}
