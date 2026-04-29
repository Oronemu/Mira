import Foundation
import CoreKit

/// Drives the embedding backfill loop and single-entry re-index. Stateless
/// by design — callers construct one and either stream progress or fire
/// and forget. The repository owns all persistence; the provider owns the
/// embedding math.
public struct EmbeddingIndexingService: Sendable {
    public struct Progress: Sendable, Hashable {
        public let indexed: Int
        public let batchSize: Int

        public init(indexed: Int, batchSize: Int) {
            self.indexed = indexed
            self.batchSize = batchSize
        }
    }

    public init() {}

    /// Repeatedly drains `fetchUnindexed` in batches until no unindexed
    /// entries remain. Yields once per processed entry so UI can show a
    /// progress counter if it wants. Cancel by deallocating the stream.
    public func backfill(
        using provider: any EmbeddingProvider,
        repository: any EntryRepository,
        batchSize: Int = 10
    ) -> AsyncThrowingStream<Progress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var indexed = 0
                    while true {
                        try Task.checkCancellation()
                        let batch = try await repository.fetchUnindexed(limit: batchSize)
                        if batch.isEmpty { break }
                        for entry in batch {
                            try Task.checkCancellation()
                            try await indexOne(id: entry.id, content: entry.content, using: provider, repository: repository)
                            indexed += 1
                            continuation.yield(Progress(indexed: indexed, batchSize: batch.count))
                        }
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

    /// Indexes a single entry. Writes an empty `Data()` when the provider
    /// cannot embed the text so we don't keep retrying the same entry.
    public func indexOne(
        id: UUID,
        content: String,
        using provider: any EmbeddingProvider,
        repository: any EntryRepository
    ) async throws {
        if let vector = try await provider.embed(content), !vector.isEmpty {
            let data = EmbeddingCodec.encode(vector)
            try await repository.updateEmbedding(id: id, data: data)
        } else {
            try await repository.updateEmbedding(id: id, data: Data())
        }
    }
}
