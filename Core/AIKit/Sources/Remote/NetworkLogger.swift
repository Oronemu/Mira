import Foundation

/// Developer-facing verbose HTTP logger for the remote AI layer.
///
/// In DEBUG builds this prints full request/response details to stdout so
/// the Xcode console shows exactly what hit the wire — URL, method, all
/// headers (with auth redacted), pretty-printed JSON bodies, response
/// headers, error bodies, and every SSE chunk. In release builds every
/// call here compiles to a no-op; production logging still goes through
/// `MiraLog` summary lines.
///
/// Uses `print` rather than `os.Logger` so large multi-line payloads
/// survive without truncation (`Logger` caps messages near 1 KB).
enum NetworkLogger {
    #if DEBUG
    nonisolated(unsafe) static var isEnabled: Bool = true
    /// Log every SSE event as it streams in. Useful for debugging stream
    /// parsing or API-level tool-use events; noisy otherwise.
    nonisolated(unsafe) static var logChunks: Bool = true
    /// Truncation limit for response bodies in error paths.
    nonisolated(unsafe) static var errorBodyLimit: Int = 8_192
    #else
    static let isEnabled: Bool = false
    static let logChunks: Bool = false
    static let errorBodyLimit: Int = 512
    #endif

    private static let sensitiveHeaders: Set<String> = [
        "authorization",
        "x-api-key",
        "api-key",
        "openai-organization",
        "openai-project",
    ]

    // MARK: - Public API

    static func request(_ request: URLRequest) {
        guard isEnabled else { return }
        var out = "\n──── HTTP ⇢ REQUEST ────"
        out += "\n\(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")"
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            out += "\nHeaders:"
            for (k, v) in headers.sorted(by: { $0.key < $1.key }) {
                let value = sensitiveHeaders.contains(k.lowercased()) ? redact(v) : v
                out += "\n  \(k): \(value)"
            }
        }
        if let body = request.httpBody {
            out += "\nBody:"
            if let pretty = prettyJSON(body) {
                out += "\n\(pretty)"
            } else if let text = String(data: body, encoding: .utf8) {
                out += "\n\(text)"
            } else {
                out += " <\(body.count) bytes, non-utf8>"
            }
        }
        out += "\n────────────────────────"
        print(out)
    }

    static func responseHead(status: Int, headers: [AnyHashable: Any], elapsed: TimeInterval) {
        guard isEnabled else { return }
        var out = "\n──── HTTP ⇠ RESPONSE ────"
        out += "\n\(status) (\(String(format: "%.2f", elapsed))s)"
        if !headers.isEmpty {
            out += "\nHeaders:"
            let sorted = headers.sorted { "\($0.key)" < "\($1.key)" }
            for (k, v) in sorted {
                out += "\n  \(k): \(v)"
            }
        }
        out += "\n────────────────────────"
        print(out)
    }

    static func responseBody(_ body: String, label: String = "Error body") {
        guard isEnabled, !body.isEmpty else { return }
        let pretty = body.data(using: .utf8).flatMap { prettyJSON($0) } ?? body
        print("\n──── HTTP \(label) ────\n\(pretty)\n────────────────────────")
    }

    static func sseEvent(name: String?, data: String) {
        guard isEnabled, logChunks else { return }
        let tag = name ?? "data"
        let pretty = data.data(using: .utf8).flatMap { prettyJSON($0) } ?? data
        print("≈ \(tag): \(pretty)")
    }

    // MARK: - Helpers

    private static func redact(_ value: String) -> String {
        guard value.count > 10 else { return "***" }
        let prefix = value.prefix(8)
        return "\(prefix)…***"
    }

    private static func prettyJSON(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(
            with: data,
            options: [.fragmentsAllowed]
        ),
        let pretty = try? JSONSerialization.data(
            withJSONObject: obj,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ),
        let string = String(data: pretty, encoding: .utf8) else {
            return nil
        }
        return string
    }
}
