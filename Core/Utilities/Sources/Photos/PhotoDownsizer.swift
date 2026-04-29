import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Downsizes user-attached photos before they're written to disk so the
/// app and iCloud sync don't carry full-resolution originals that the
/// journaling UI never renders at anything close to native size.
public enum PhotoDownsizer {
    /// Longest-edge target in pixels. Journal thumbnails and detail views
    /// never exceed this; anything larger is wasted bytes.
    public static let maxDimension: Int = 2048

    /// JPEG compression quality used when re-encoding the thumbnail.
    public static let compressionQuality: Double = 0.8

    /// Returns downsized JPEG bytes. If the source can't be decoded (not
    /// an image, corrupt), returns the original `data` untouched — the
    /// journal save path should never fail because of a rejected photo.
    public static func downsize(_ data: Data) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            return data
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return data
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return data
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, thumbnail, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return data
        }
        return output as Data
    }
}
