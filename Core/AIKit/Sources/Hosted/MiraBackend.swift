import Foundation
import CoreKit
import Utilities

/// Compile-time configuration for the Mira-hosted AI proxy. URL
/// resolution lives in `Utilities.MiraBackendURL` so the Subscriptions
/// module can hit the same worker without importing AIKit.
public enum MiraBackend {
    public static var defaultConfig: HostedAIProvider.Config {
        HostedAIProvider.Config(baseURL: MiraBackendURL.resolve())
    }
}
