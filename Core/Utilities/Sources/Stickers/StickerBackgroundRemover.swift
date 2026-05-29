import Foundation
import CoreImage
import Vision
import UIKit

public enum StickerBackgroundRemoverError: LocalizedError, Sendable {
    case decodeFailed
    case noSubjectDetected
    case maskingFailed

    public var errorDescription: String? {
        switch self {
        case .decodeFailed:
            String(localized: "We couldn't read that photo. Try another image.")
        case .noSubjectDetected:
            String(localized: "No subject found. Pick a photo with a clear foreground.")
        case .maskingFailed:
            String(localized: "Something went wrong while cutting out the subject.")
        }
    }
}

/// Turns a regular photo into a transparent-background sticker PNG using
/// Vision's `VNGenerateForegroundInstanceMaskRequest` — the same engine
/// behind iOS's "Lift Subject from Background" gesture. All processing
/// happens on-device; nothing leaves the user's phone.
///
/// The actor wrapper isolates the Vision request handler so we don't
/// accidentally share its mutable state across calls. Real cost is the
/// Vision compute — callers should drive this from a `.task` and show a
/// spinner.
public actor StickerBackgroundRemover {
    public init() {}

    /// Produces sticker PNG bytes (alpha preserved) from raw image data.
    /// The mask is cropped to the subject's bounding box so the resulting
    /// sticker doesn't carry empty pixels from the original frame.
    public func makeSticker(from data: Data) async throws -> Data {
        guard let cgSource = Self.cgImage(from: data) else {
            throw StickerBackgroundRemoverError.decodeFailed
        }
        let handler = VNImageRequestHandler(cgImage: cgSource, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
        } catch {
            throw StickerBackgroundRemoverError.maskingFailed
        }
        guard let observation = request.results?.first,
              !observation.allInstances.isEmpty else {
            throw StickerBackgroundRemoverError.noSubjectDetected
        }
        let maskedPixelBuffer: CVPixelBuffer
        do {
            maskedPixelBuffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
        } catch {
            throw StickerBackgroundRemoverError.maskingFailed
        }
        let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
        let context = CIContext()
        guard let cgOutput = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw StickerBackgroundRemoverError.maskingFailed
        }
        // UIImage → PNG keeps the alpha channel; JPEG would flatten the
        // transparency we just worked to produce.
        let uiImage = UIImage(cgImage: cgOutput)
        guard let png = uiImage.pngData() else {
            throw StickerBackgroundRemoverError.maskingFailed
        }
        return png
    }

    /// Decodes input bytes via ImageIO so HEIC/JPEG/PNG all flow through
    /// the same path. UIImage(data:) would also work but loses the EXIF
    /// orientation on some HEIC frames — ImageIO applies orientation up
    /// front so Vision sees the upright pixels.
    private nonisolated static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
    }
}
