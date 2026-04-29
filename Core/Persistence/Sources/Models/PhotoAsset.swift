import Foundation
import SwiftData

@Model
public final class PhotoAsset {
    @Attribute(.unique) public var id: UUID
    public var relativePath: String
    public var createdAt: Date
    public var entry: Entry?

    public init(id: UUID = UUID(), relativePath: String, createdAt: Date = .now) {
        self.id = id
        self.relativePath = relativePath
        self.createdAt = createdAt
    }
}
