import Foundation
import os
import CoreKit
import Utilities

/// `AIProvider` that routes generation through Mira's Cloudflare Worker.
/// The worker authenticates the caller via the StoreKit JWS, enforces
/// monthly limits, and proxies to Anthropic — keeping the Claude API key
/// off the device and consolidating Pro AI access behind one integration
/// point.
///
/// `HostedAIProvider` is intent-aware: each AI surface (Ask Mira, weekly
/// reflection auto/manual) constructs a provider tagged with its intent
/// so the worker can apply per-feature usage budgets without the iOS
/// client baking those rules in. `AIService` selects the right intent
/// when it dispatches a request.
public actor HostedAIProvider: AIProvider {
    public enum Intent: String, Sendable, Hashable, Codable {
        case askMira
        case weeklyReflectionAuto
        case weeklyReflectionManual
        /// Internal helper call used by AskMira to rephrase a follow-up
        /// question for retrieval. Counts against neither user quota nor
        /// the surface they triggered — it's a mechanism, not a turn.
        case askMiraRewrite
        /// Internal helper call used by AskMira to generate a polished
        /// title for the first turn of a chat. Same rationale as
        /// `askMiraRewrite` — does not consume the user's monthly cap.
        case askMiraTitle
    }

    public struct Config: Sendable, Hashable {
        public let baseURL: URL
        public let appAttestKeyID: String?
        public let appAttestAssertion: String?

        public init(
            baseURL: URL,
            appAttestKeyID: String? = nil,
            appAttestAssertion: String? = nil
        ) {
            self.baseURL = baseURL
            self.appAttestKeyID = appAttestKeyID
            self.appAttestAssertion = appAttestAssertion
        }
    }

    private static let log = MiraLog.logger(.network)

    private let config: Config
    private let intent: Intent
    private let subscriptionService: any SubscriptionService
    private let session: URLSession

    public init(
        config: Config,
        intent: Intent,
        subscriptionService: any SubscriptionService,
        session: URLSession = .shared
    ) {
        self.config = config
        self.intent = intent
        self.subscriptionService = subscriptionService
        self.session = session
    }

    public var isAvailable: Bool {
        get async {
            if await subscriptionService.latestSignedTransaction() != nil { return true }
            if await subscriptionService.redeemUserID != nil { return true }
            return false
        }
    }

    public func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        let credential: BackendCredential
        if let jws = await subscriptionService.latestSignedTransaction() {
            credential = .jws(jws)
        } else if let rid = await subscriptionService.redeemUserID {
            credential = .redeem(rid)
        } else {
            throw AIError.providerUnavailable
        }

        let urlRequest = try makeURLRequest(request: request, credential: credential)

        Self.log.info("→ hosted AI request • intent=\(self.intent.rawValue, privacy: .public) • messages=\(request.messages.count, privacy: .public)")

        let session = self.session
        let backend = AnthropicBackend()

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIError.requestFailed("Non-HTTP response from hosted AI")
                    }
                    try Self.mapHTTPStatus(http)

                    for try await event in SSEParser.events(from: bytes) {
                        if let chunk = backend.parseDelta(from: event) {
                            continuation.yield(chunk)
                            if chunk.isFinal { break }
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIError.cancelled)
                } catch let error as AIError {
                    continuation.finish(throwing: error)
                } catch {
                    Self.log.error("hosted AI failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: AIError.requestFailed(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private

    private enum BackendCredential {
        case jws(String)
        case redeem(String)
    }

    private func makeURLRequest(request: AIRequest, credential: BackendCredential) throws -> URLRequest {
        let url = config.baseURL.appendingPathComponent("v1/ai/messages")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let keyID = config.appAttestKeyID, let assertion = config.appAttestAssertion {
            urlRequest.setValue(keyID, forHTTPHeaderField: "X-App-Attest-Key-ID")
            urlRequest.setValue(assertion, forHTTPHeaderField: "X-App-Attest-Assertion")
        }

        let system = request.messages.first(where: { $0.role == .system })?.content
        let messages: [[String: String]] = request.messages
            .filter { $0.role != .system }
            .map { ["role": $0.role.rawValue, "content": $0.content] }

        var inner: [String: Any] = [
            "messages": messages,
            "max_tokens": request.maxTokens ?? 1024,
            "temperature": request.temperature,
            "stream": true,
        ]
        if let system { inner["system"] = system }

        var payload: [String: Any] = [
            "intent": intent.rawValue,
            "request": inner,
        ]
        switch credential {
        case .jws(let jws):
            payload["signedTransaction"] = jws
        case .redeem(let rid):
            payload["redeemUserId"] = rid
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return urlRequest
    }

    private static func mapHTTPStatus(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299: return
        case 401, 403: throw AIError.providerUnavailable
        case 402: throw AIError.providerUnavailable
        case 429: throw AIError.rateLimited
        default:
            throw AIError.requestFailed("Hosted AI returned \(response.statusCode)")
        }
    }
}
