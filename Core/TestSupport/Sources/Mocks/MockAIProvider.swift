import Foundation
import CoreKit

public actor MockAIProvider: AIProvider {
    private let scriptedChunks: [String]
    private let shouldFail: Bool

    public init(scriptedChunks: [String] = ["mock "], shouldFail: Bool = false) {
        self.scriptedChunks = scriptedChunks
        self.shouldFail = shouldFail
    }

    public var isAvailable: Bool { !shouldFail }

    public func stream(_ request: AIRequest) async throws -> AsyncThrowingStream<AIResponseChunk, Error> {
        if shouldFail { throw AIError.providerUnavailable }
        let chunks = scriptedChunks
        return AsyncThrowingStream { continuation in
            Task {
                for (index, text) in chunks.enumerated() {
                    let isFinal = index == chunks.count - 1
                    continuation.yield(AIResponseChunk(textDelta: text, isFinal: isFinal))
                }
                continuation.finish()
            }
        }
    }
}
