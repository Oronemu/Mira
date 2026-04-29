import Foundation
import CoreKit

struct OpenAIBackend: RemoteBackend {
    static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func makeRequest(_ request: AIRequest, model: String, apiKey: String) throws -> URLRequest {
        try Self.makeOpenAIStyleRequest(request, model: model, apiKey: apiKey, endpoint: Self.endpoint)
    }

    func parseDelta(from event: SSEEvent) -> AIResponseChunk? {
        Self.parseOpenAIStyleDelta(from: event)
    }

    static func makeOpenAIStyleRequest(_ request: AIRequest, model: String, apiKey: String, endpoint: URL) throws -> URLRequest {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let messages = request.messages.map {
            ["role": $0.role.rawValue, "content": $0.content]
        }
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": request.temperature,
            "stream": true,
        ]
        if let maxTokens = request.maxTokens {
            body["max_tokens"] = maxTokens
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    static func parseOpenAIStyleDelta(from event: SSEEvent) -> AIResponseChunk? {
        if event.data == "[DONE]" {
            return AIResponseChunk(textDelta: "", isFinal: true)
        }
        guard let data = event.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first else {
            return nil
        }
        if let delta = first["delta"] as? [String: Any],
           let content = delta["content"] as? String,
           !content.isEmpty {
            return AIResponseChunk(textDelta: content, isFinal: false)
        }
        if let reason = first["finish_reason"] as? String, !reason.isEmpty {
            return AIResponseChunk(textDelta: "", isFinal: true)
        }
        return nil
    }
}
