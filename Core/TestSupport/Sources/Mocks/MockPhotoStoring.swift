import Foundation
import CoreKit

public actor MockPhotoStoring: PhotoStoring {
    public private(set) var stored: [String: Data] = [:]
    public private(set) var deleted: [String] = []

    public init() {}

    public func save(_ data: Data) async throws -> PhotoAssetSnapshot {
        try await save(data, id: UUID())
    }

    public func save(_ data: Data, id: UUID) async throws -> PhotoAssetSnapshot {
        let relativePath = "Photos/\(id.uuidString).jpg"
        stored[relativePath] = data
        return PhotoAssetSnapshot(id: id, relativePath: relativePath)
    }

    public func exists(relativePath: String) async -> Bool {
        stored[relativePath] != nil
    }

    public func read(relativePath: String) async throws -> Data {
        guard let data = stored[relativePath] else {
            throw NSError(domain: "MockPhotoStoring", code: 404)
        }
        return data
    }

    public func delete(relativePath: String) async throws {
        stored.removeValue(forKey: relativePath)
        deleted.append(relativePath)
    }
}
