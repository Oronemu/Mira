import SwiftUI

private struct PaywallPresenterKey: EnvironmentKey {
    static let defaultValue: any PaywallPresenter = UnimplementedPaywallPresenter()
}

public extension EnvironmentValues {
    var paywallPresenter: any PaywallPresenter {
        get { self[PaywallPresenterKey.self] }
        set { self[PaywallPresenterKey.self] = newValue }
    }
}
