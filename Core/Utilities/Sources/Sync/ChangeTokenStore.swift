import Foundation
import CoreKit

/// Persists the CloudKit server change token between launches so the
/// puller fetches only deltas instead of full zone history on every
/// run. A missing file means "start from scratch" — used on first
/// install and after a forced resync.
public actor ChangeTokenStore {
    private let url: URL

    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    public func load() -> CloudKitChangeToken? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return CloudKitChangeToken(data: data)
    }

    public func save(_ token: CloudKitChangeToken) throws {
        try token.data.write(to: url, options: .atomic)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
