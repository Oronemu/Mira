import SwiftUI

private struct AIProviderKey: EnvironmentKey {
    static let defaultValue: any AIProvider = UnimplementedAIProvider()
}

public extension EnvironmentValues {
    var aiProvider: any AIProvider {
        get { self[AIProviderKey.self] }
        set { self[AIProviderKey.self] = newValue }
    }
}
