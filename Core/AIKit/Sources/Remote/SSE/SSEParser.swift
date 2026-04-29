import Foundation

/// Streams `SSEEvent`s from a `URLSession.AsyncBytes` stream. Follows
/// the WHATWG SSE spec: lines starting with `:` are comments, fields are
/// `name:value` (an optional single space after the colon is stripped),
/// and an empty line dispatches the accumulated event.
///
/// Splits lines manually off the raw byte stream because `bytes.lines`
/// on iOS 26 swallows the empty separator lines between events — which
/// collapses a multi-event SSE stream into one giant event.
public enum SSEParser {
    public static func events(from bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var event: String? = nil
                    var dataLines: [String] = []
                    var id: String? = nil
                    var lineBuffer = [UInt8]()

                    func handle(_ line: String) {
                        if line.isEmpty {
                            if !dataLines.isEmpty || event != nil {
                                continuation.yield(SSEEvent(
                                    event: event,
                                    data: dataLines.joined(separator: "\n"),
                                    id: id
                                ))
                            }
                            event = nil
                            dataLines = []
                            id = nil
                            return
                        }
                        if line.hasPrefix(":") { return }
                        let (field, value) = parseField(line)
                        switch field {
                        case "event": event = value
                        case "data": dataLines.append(value)
                        case "id": id = value
                        default: break
                        }
                    }

                    func flushLine() {
                        // Handle CRLF: drop trailing \r if present.
                        if lineBuffer.last == 0x0D { lineBuffer.removeLast() }
                        let text = String(decoding: lineBuffer, as: UTF8.self)
                        lineBuffer.removeAll(keepingCapacity: true)
                        handle(text)
                    }

                    for try await byte in bytes {
                        if byte == 0x0A { // \n — end of line
                            flushLine()
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    // Drain anything left after the stream ends.
                    if !lineBuffer.isEmpty { flushLine() }
                    if !dataLines.isEmpty || event != nil {
                        continuation.yield(SSEEvent(
                            event: event,
                            data: dataLines.joined(separator: "\n"),
                            id: id
                        ))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func parseField(_ line: String) -> (field: String, value: String) {
        guard let colon = line.firstIndex(of: ":") else {
            return (line, "")
        }
        let field = String(line[..<colon])
        var valueStart = line.index(after: colon)
        if valueStart < line.endIndex, line[valueStart] == " " {
            valueStart = line.index(after: valueStart)
        }
        return (field, String(line[valueStart...]))
    }
}
