import Foundation
import os

/// Centralised `Logger` category factory. Every subsystem call goes through
/// here so the bundle identifier stays consistent and grep-able.
public enum MiraLog {
    public static let subsystem = "com.veilbytesoft.Mira"

    public enum Category: String {
        case ai = "AI"
        case network = "Network"
        case models = "Models"
        case sync = "Sync"
        case storage = "Storage"
        case ui = "UI"
        case background = "Background"
        case widgets = "Widgets"
        case general = "General"
    }

    public static func logger(_ category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
