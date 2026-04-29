import SwiftUI
import UIKit

/// Thin SwiftUI wrapper over `UIActivityViewController`. Present via
/// `.sheet(item:)` passing an identifiable URL container.
public struct ShareSheet: UIViewControllerRepresentable {
    public let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// `URL` does not conform to `Identifiable` out of the box; this wrapper
/// lets callers drive `.sheet(item:)` with an export result.
public struct IdentifiableURL: Identifiable, Hashable {
    public let url: URL
    public var id: URL { url }

    public init(url: URL) {
        self.url = url
    }
}
