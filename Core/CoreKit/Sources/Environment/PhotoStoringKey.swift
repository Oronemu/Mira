import SwiftUI

private struct PhotoStoringKey: EnvironmentKey {
    static let defaultValue: any PhotoStoring = UnimplementedPhotoStoring()
}

public extension EnvironmentValues {
    var photoStoring: any PhotoStoring {
        get { self[PhotoStoringKey.self] }
        set { self[PhotoStoringKey.self] = newValue }
    }
}
