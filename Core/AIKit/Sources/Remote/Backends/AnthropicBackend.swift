import Foundation
import CoreKit

struct AnthropicBackend: RemoteBackend {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let version = "2023-06-01"

    func makeRequest(_ request: AIRequest, model: String, apiKey: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.version, forHTTPHeaderField: "anthropic-version")

        let system = request.messages.first(where: { $0.role == .system })?.content
        let messages = request.messages
            .filter { $0.role != .system }
            .map { ["role": $0.role.rawValue, "content": $0.content] }

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": request.maxTokens ?? 1024,
            "temperature": request.temperature,
            "stream": true,
        ]
        if let system { body["system"] = system }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    func parseDelta(from event: SSEEvent) -> AIResponseChunk? {
        if event.event == "message_stop" {
            return AIResponseChunk(textDelta: "", isFinal: true)
        }
        guard event.event == "content_block_delta" else { return nil }
        guard let data = event.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let delta = json["delta"] as? [String: Any],
              let text = delta["text"] as? String else {
            return nil
        }
        return AIResponseChunk(textDelta: text, isFinal: false)
    }
}
