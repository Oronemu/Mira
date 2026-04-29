import Foundation
import CoreKit

struct OpenRouterBackend: RemoteBackend {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    func makeRequest(_ request: AIRequest, model: String, apiKey: String) throws -> URLRequest {
        var urlRequest = try OpenAIBackend.makeOpenAIStyleRequest(
            request,
            model: model,
            apiKey: apiKey,
            endpoint: Self.endpoint
        )
        // OpenRouter uses these optional headers to attribute / rank apps.
        urlRequest.setValue("https://github.com/oronemu/mira", forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue("Mira", forHTTPHeaderField: "X-Title")
        return urlRequest
    }

    func parseDelta(from event: SSEEvent) -> AIResponseChunk? {
        OpenAIBackend.parseOpenAIStyleDelta(from: event)
    }
}
