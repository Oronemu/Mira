import SwiftUI

private struct CustomStickerStoringKey: EnvironmentKey {
    static let defaultValue: any CustomStickerStoring = UnimplementedCustomStickerStoring()
}

public extension EnvironmentValues {
    var customStickerStore: any CustomStickerStoring {
        get { self[CustomStickerStoringKey.self] }
        set { self[CustomStickerStoringKey.self] = newValue }
    }
}
