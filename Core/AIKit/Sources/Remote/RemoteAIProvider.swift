import Foundation
import os
import CoreKit
import Utilities

/// Streams completions from Anthropic / OpenAI / OpenRouter over SSE.
/// Retries once on 429 or 5xx with exponential backoff; maps other
/// non-2xx responses to `AIError`.
public actor RemoteAIProvider: AIProvider {
    public struct Credentials: Sendable, Hashable {
        public let config: RemoteConfig
        public let apiKey: String

        public init(config: RemoteConfig, apiKey: String) {
            self.config = config
            self.apiKey = apiKey
        }
    }

    private static let log = MiraLog.logger(.network)

    private let credentials: Credentials
    private let session: URLSession
    private let maxRetries: Int

    public init(credentials: Credentials, session: URLSession = .shared, maxRetries: Int = 2) {
        self.credentials = credentials
        self.session = session
        self.maxRetries = maxRetries
    }

    public var isAvailable: Bool {
        get async { !credentials.apiKey.isEmpty }
    }

    public func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        let backend = Self.backend(for: credentials.config.provider)
        let urlRequest: URLRequest
        do {
            urlRequest = try backend.makeRequest(
                request,
                model: credentials.config.model,
                apiKey: credentials.apiKey
            )
        } catch {
            Self.log.error("Failed to build \(self.credentials.config.provider.rawValue, privacy: .public) request for model \(self.credentials.config.model, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw AIError.requestFailed(error.localizedDescription)
        }

        let providerName = credentials.config.provider.rawValue
        let modelName = credentials.config.model
        let messageCount = request.messages.count
        let session = self.session
        let maxRetries = self.maxRetries

        Self.log.info("→ \(providerName, privacy: .public) request • model=\(modelName, privacy: .public) • messages=\(messageCount, privacy: .public) • url=\(urlRequest.url?.absoluteString ?? "?", privacy: .public)")
        NetworkLogger.request(urlRequest)

        return AsyncThrowingStream { continuation in
            let task = Task {
                let startedAt = Date.now
                do {
                    try await Self.run(
                        urlRequest: urlRequest,
                        backend: backend,
                        session: session,
                        maxRetries: maxRetries,
                        providerName: providerName,
                        modelName: modelName,
                        continuation: continuation
                    )
                    let elapsed = Date.now.timeIntervalSince(startedAt)
                    Self.log.info("✓ \(providerName, privacy: .public) response finished in \(elapsed, format: .fixed(precision: 2), privacy: .public)s")
                } catch is CancellationError {
                    Self.log.info("× \(providerName, privacy: .public) request cancelled")
                    continuation.finish(throwing: AIError.cancelled)
                } catch let error as AIError {
                    Self.log.error("✗ \(providerName, privacy: .public) request failed: \(error.errorDescription ?? "unknown", privacy: .public)")
                    continuation.finish(throwing: error)
                } catch {
                    let nsError = error as NSError
                    Self.log.error("✗ \(providerName, privacy: .public) transport error: \(error.localizedDescription, privacy: .public) • domain=\(nsError.domain, privacy: .public) • code=\(nsError.code, privacy: .public)")
                    continuation.finish(throwing: AIError.requestFailed(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func run(
        urlRequest: URLRequest,
        backend: any RemoteBackend,
        session: URLSession,
        maxRetries: Int,
        providerName: String,
        modelName: String,
        continuation: AsyncThrowingStream<AIResponseChunk, Error>.Continuation
    ) async throws {
        var attempt = 0
        while true {
            let sentAt = Date.now
            let (bytes, response) = try await session.bytes(for: urlRequest)
            let elapsed = Date.now.timeIntervalSince(sentAt)
            guard let http = response as? HTTPURLResponse else {
                log.error("\(providerName, privacy: .public): non-HTTP response")
                throw AIError.requestFailed("Non-HTTP response")
            }
            NetworkLogger.responseHead(
                status: http.statusCode,
                headers: http.allHeaderFields,
                elapsed: elapsed
            )
            switch http.statusCode {
            case 200:
                try await drain(bytes: bytes, backend: backend, continuation: continuation)
                continuation.finish()
                return
            case 401, 403:
                let body = await readErrorBody(bytes)
                NetworkLogger.responseBody(body, label: "Auth error body")
                log.error("\(providerName, privacy: .public) \(http.statusCode, privacy: .public) auth error • model=\(modelName, privacy: .public) • body=\(body, privacy: .public)")
                throw AIError.invalidAPIKey
            case 429:
                let body = await readErrorBody(bytes)
                NetworkLogger.responseBody(body, label: "Rate-limit body")
                log.warning("\(providerName, privacy: .public) 429 rate limited (attempt \(attempt, privacy: .public)/\(maxRetries, privacy: .public)) • body=\(body, privacy: .public)")
                guard attempt < maxRetries else { throw AIError.rateLimited }
                try await Task.sleep(nanoseconds: backoff(attempt))
                attempt += 1
            case 500...599:
                let body = await readErrorBody(bytes)
                NetworkLogger.responseBody(body, label: "Server error body")
                log.warning("\(providerName, privacy: .public) \(http.statusCode, privacy: .public) server error (attempt \(attempt, privacy: .public)/\(maxRetries, privacy: .public)) • body=\(body, privacy: .public)")
                guard attempt < maxRetries else {
                    throw AIError.requestFailed("Server error (\(http.statusCode)) — \(body)")
                }
                try await Task.sleep(nanoseconds: backoff(attempt))
                attempt += 1
            default:
                let body = await readErrorBody(bytes)
                NetworkLogger.responseBody(body, label: "Error body")
                log.error("\(providerName, privacy: .public) \(http.statusCode, privacy: .public) unexpected • model=\(modelName, privacy: .public) • body=\(body, privacy: .public)")
                throw AIError.requestFailed("HTTP \(http.statusCode) — \(body)")
            }
        }
    }

    /// Drains a stalled/error HTTP body into a short string so the caller
    /// can surface the provider's actual error message in logs and errors.
    /// Cap expands in DEBUG via `NetworkLogger.errorBodyLimit`.
    private static func readErrorBody(_ bytes: URLSession.AsyncBytes) async -> String {
        let limit = NetworkLogger.errorBodyLimit
        var buffer = Data()
        do {
            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= limit { break }
            }
        } catch {
            // Ignore — we're already on the error path.
        }
        let text = String(data: buffer, encoding: .utf8) ?? ""
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func drain(
        bytes: URLSession.AsyncBytes,
        backend: any RemoteBackend,
        continuation: AsyncThrowingStream<AIResponseChunk, Error>.Continuation
    ) async throws {
        var sawFinal = false
        for try await event in SSEParser.events(from: bytes) {
            NetworkLogger.sseEvent(name: event.event, data: event.data)
            guard let chunk = backend.parseDelta(from: event) else { continue }
            continuation.yield(chunk)
            if chunk.isFinal {
                sawFinal = true
                break
            }
        }
        if !sawFinal {
            continuation.yield(AIResponseChunk(textDelta: "", isFinal: true))
        }
    }

    private static func backoff(_ attempt: Int) -> UInt64 {
        // 500ms, then 1s.
        let baseMs: UInt64 = 500
        return baseMs * (1 << UInt64(attempt)) * 1_000_000
    }

    private static func backend(for provider: RemoteConfig.Provider) -> any RemoteBackend {
        switch provider {
        case .anthropic: AnthropicBackend()
        case .openai: OpenAIBackend()
        case .openrouter: OpenRouterBackend()
        }
    }
}
