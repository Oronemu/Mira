import Foundation

/// Kept in sync with `App/Sources/AppGroup.swift`. Duplicated rather than
/// shared via a module so the widget extension can depend on zero app
/// sources (linker boundary is cleaner).
enum WidgetAppGroup {
    static let identifier = "group.com.veilbytesoft.Mira"
}
