import Foundation
import CoreKit

/// One entry + its cosine similarity to the query vector, ordered high→low
/// by `VectorIndex.topK`.
public struct ScoredEntry: Sendable, Hashable {
    public let entry: EmbeddedEntry
    public let score: Float

    public init(entry: EmbeddedEntry, score: Float) {
        self.entry = entry
        self.score = score
    }
}

/// Linear-scan cosine similarity search over `EmbeddedEntry` records.
/// No ANN index — the corpus is small (personal journal) so a scan is
/// fast enough and trades memory for simplicity.
public enum VectorIndex {
    public static func topK(query: [Float], against entries: [EmbeddedEntry], k: Int) -> [ScoredEntry] {
        guard k > 0, !query.isEmpty else { return [] }
        let queryNorm = norm(query)
        guard queryNorm > 0 else { return [] }

        let scored: [ScoredEntry] = entries.compactMap { entry in
            guard entry.embedding.count == query.count else { return nil }
            let entryNorm = norm(entry.embedding)
            guard entryNorm > 0 else { return nil }
            let dot = dotProduct(query, entry.embedding)
            return ScoredEntry(entry: entry, score: dot / (queryNorm * entryNorm))
        }
        return Array(scored.sorted { $0.score > $1.score }.prefix(k))
    }

    private static func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<a.count { sum += a[i] * b[i] }
        return sum
    }

    private static func norm(_ vector: [Float]) -> Float {
        var sum: Float = 0
        for value in vector { sum += value * value }
        return sqrt(sum)
    }
}
