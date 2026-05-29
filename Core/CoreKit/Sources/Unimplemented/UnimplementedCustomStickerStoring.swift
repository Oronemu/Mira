import Foundation

public struct UnimplementedCustomStickerStoring: CustomStickerStoring {
    public init() {}

    public func save(_ pngData: Data) async throws -> CustomStickerAsset {
        unimplemented(#function)
    }

    public func save(_ pngData: Data, id: UUID, createdAt: Date) async throws -> CustomStickerAsset {
        unimplemented(#function)
    }

    public func exists(id: UUID) async -> Bool {
        unimplemented(#function)
    }

    public func read(relativePath: String) async throws -> Data {
        unimplemented(#function)
    }

    public func delete(id: UUID) async throws {
        unimplemented(#function)
    }

    public func list() async throws -> [CustomStickerAsset] {
        unimplemented(#function)
    }

    public func changes() -> AsyncStream<CustomStickerChange> {
        AsyncStream { $0.finish() }
    }

    private func unimplemented(_ method: String) -> Never {
        assertionFailure("UnimplementedCustomStickerStoring.\(method) called — wire a real CustomStickerStoring in ServiceContainer.")
        fatalError("UnimplementedCustomStickerStoring.\(method)")
    }
}
