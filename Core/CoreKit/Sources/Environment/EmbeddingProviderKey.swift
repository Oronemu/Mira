import SwiftUI

private struct EmbeddingProviderKey: EnvironmentKey {
    static let defaultValue: any EmbeddingProvider = UnimplementedEmbeddingProvider()
}

public extension EnvironmentValues {
    var embeddingProvider: any EmbeddingProvider {
        get { self[EmbeddingProviderKey.self] }
        set { self[EmbeddingProviderKey.self] = newValue }
    }
}
