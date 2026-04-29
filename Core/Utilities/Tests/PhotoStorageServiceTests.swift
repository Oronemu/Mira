import Foundation
import Testing
@testable import Utilities

@Suite("PhotoStorageService")
struct PhotoStorageServiceTests {
    private func tempService() throws -> PhotoStorageService {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoStorageServiceTests-\(UUID().uuidString)", isDirectory: true)
        return try PhotoStorageService(directoryURL: dir)
    }

    @Test("save then read round-trip")
    func saveRead() async throws {
        let service = try tempService()
        let bytes = Data("hello".utf8)

        let snapshot = try await service.save(bytes)
        let read = try await service.read(relativePath: snapshot.relativePath)

        #expect(read == bytes)
        #expect(snapshot.relativePath.hasPrefix("Photos/"))
    }

    @Test("delete removes the file")
    func delete() async throws {
        let service = try tempService()
        let snapshot = try await service.save(Data("bye".utf8))

        try await service.delete(relativePath: snapshot.relativePath)

        await #expect(throws: PhotoStorageError.self) {
            _ = try await service.read(relativePath: snapshot.relativePath)
        }
    }

    @Test("save with explicit id lands at the deterministic path")
    func saveWithExplicitID() async throws {
        let service = try tempService()
        let id = UUID()
        let bytes = Data("pulled".utf8)

        let snapshot = try await service.save(bytes, id: id)

        #expect(snapshot.id == id)
        #expect(snapshot.relativePath == "Photos/\(id.uuidString).jpg")
        #expect(try await service.read(relativePath: snapshot.relativePath) == bytes)
    }

    @Test("exists reports presence without throwing")
    func existsReflectsPresence() async throws {
        let service = try tempService()
        let id = UUID()
        let path = "Photos/\(id.uuidString).jpg"

        #expect(await service.exists(relativePath: path) == false)
        _ = try await service.save(Data("x".utf8), id: id)
        #expect(await service.exists(relativePath: path) == true)
    }
}
