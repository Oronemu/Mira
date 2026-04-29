import Foundation
import CoreKit

/// Provider-specific request shaping + SSE event decoding. Each backend
/// knows its own URL, auth header, JSON body format, and delta extractor.
/// `RemoteAIProvider` owns the generic transport loop and error mapping.
protocol RemoteBackend: Sendable {
    func makeRequest(_ request: AIRequest, model: String, apiKey: String) throws -> URLRequest
    func parseDelta(from event: SSEEvent) -> AIResponseChunk?
}
