import Foundation

public struct UnimplementedPhotoStoring: PhotoStoring {
    public init() {}

    public func save(_ data: Data) async throws -> PhotoAssetSnapshot {
        unimplemented(#function)
    }

    public func save(_ data: Data, id: UUID) async throws -> PhotoAssetSnapshot {
        unimplemented(#function)
    }

    public func exists(relativePath: String) async -> Bool {
        unimplemented(#function)
    }

    public func read(relativePath: String) async throws -> Data {
        unimplemented(#function)
    }

    public func delete(relativePath: String) async throws {
        unimplemented(#function)
    }

    private func unimplemented(_ method: String) -> Never {
        assertionFailure("UnimplementedPhotoStoring.\(method) called — wire a real PhotoStoring in ServiceContainer.")
        fatalError("UnimplementedPhotoStoring.\(method)")
    }
}
