import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Payload carried during a drag from `StickerPickerSheet` to the editing
/// canvas. The custom UTI keeps the system from offering generic drop-zones
/// (e.g. text fields) as targets — only views explicitly registering the
/// type via `.dropDestination(for: StickerDragPayload.self)` light up.
public struct StickerDragPayload: Codable, Sendable, Transferable {
    public let libraryRef: String

    public init(libraryRef: String) {
        self.libraryRef = libraryRef
    }

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .miraSticker)
    }
}

public extension UTType {
    /// In-app drag UTI. Not registered in Info.plist by design — used only
    /// for in-process drag/drop from the picker to the canvas; OS-wide
    /// recognition isn't needed.
    static let miraSticker = UTType(exportedAs: "com.veilbytesoft.mira.sticker")
}
