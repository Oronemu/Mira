import Foundation

/// One server-sent event. `event` and `id` may be nil; `data` carries the
/// joined data lines (multi-line data uses `\n` per the spec).
public struct SSEEvent: Sendable, Hashable {
    public let event: String?
    public let data: String
    public let id: String?

    public init(event: String? = nil, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}
