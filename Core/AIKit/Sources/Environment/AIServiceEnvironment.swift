import SwiftUI

private struct AIServiceKey: EnvironmentKey {
    static let defaultValue: AIService = AIService()
}

public extension EnvironmentValues {
    var aiService: AIService {
        get { self[AIServiceKey.self] }
        set { self[AIServiceKey.self] = newValue }
    }
}
