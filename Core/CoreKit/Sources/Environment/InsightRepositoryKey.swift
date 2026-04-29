import SwiftUI

private struct InsightRepositoryKey: EnvironmentKey {
    static let defaultValue: any InsightRepository = UnimplementedInsightRepository()
}

public extension EnvironmentValues {
    var insightRepository: any InsightRepository {
        get { self[InsightRepositoryKey.self] }
        set { self[InsightRepositoryKey.self] = newValue }
    }
}
