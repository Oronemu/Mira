import SwiftUI

private struct AskMiraRepositoryKey: EnvironmentKey {
    static let defaultValue: any AskMiraRepository = UnimplementedAskMiraRepository()
}

public extension EnvironmentValues {
    var askMiraRepository: any AskMiraRepository {
        get { self[AskMiraRepositoryKey.self] }
        set { self[AskMiraRepositoryKey.self] = newValue }
    }
}
