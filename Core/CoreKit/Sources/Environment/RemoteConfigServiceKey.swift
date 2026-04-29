import SwiftUI

private struct RemoteConfigServiceKey: EnvironmentKey {
    static let defaultValue: any RemoteConfigService = UnimplementedRemoteConfigService()
}

public extension EnvironmentValues {
    var remoteConfigService: any RemoteConfigService {
        get { self[RemoteConfigServiceKey.self] }
        set { self[RemoteConfigServiceKey.self] = newValue }
    }
}
