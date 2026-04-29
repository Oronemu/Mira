import Foundation

/// Single canonical app group identifier shared by the app and the
/// widget extension. Any code that opens the SwiftData store or reads
/// shared photos must route through here.
enum AppGroup {
    static let identifier = "group.com.veilbytesoft.Mira"
}
