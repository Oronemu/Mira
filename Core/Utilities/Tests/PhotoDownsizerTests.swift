import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Utilities

@Suite("PhotoDownsizer")
struct PhotoDownsizerTests {
    private static let red = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
    private static let blue = CGColor(red: 0, green: 0, blue: 1, alpha: 1)

    @Test("Downsizes images larger than the cap to 2048 on the long edge")
    func downsizeCapsLongEdge() throws {
        let large = try makeJPEG(width: 4000, height: 3000, color: Self.red)

        let result = PhotoDownsizer.downsize(large)

        let dims = try dimensions(of: result)
        #expect(max(dims.width, dims.height) == PhotoDownsizer.maxDimension)
        #expect(result.count < large.count)
    }

    @Test("Leaves small images effectively unchanged in resolution")
    func smallImageKeepsResolution() throws {
        let small = try makeJPEG(width: 800, height: 600, color: Self.blue)

        let result = PhotoDownsizer.downsize(small)

        let dims = try dimensions(of: result)
        #expect(dims.width == 800)
        #expect(dims.height == 600)
    }

    @Test("Non-image input passes through untouched")
    func nonImagePassesThrough() {
        let garbage = Data("not an image".utf8)
        #expect(PhotoDownsizer.downsize(garbage) == garbage)
    }

    // MARK: - Helpers

    private func makeJPEG(width: Int, height: Int, color: CGColor) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            Issue.record("Failed to create CGContext")
            return Data()
        }
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = ctx.makeImage() else {
            Issue.record("Failed to produce CGImage")
            return Data()
        }
        let output = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            Issue.record("Failed to create image destination")
            return Data()
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            Issue.record("Failed to finalize JPEG")
            return Data()
        }
        return output as Data
    }

    private func dimensions(of data: Data) throws -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            Issue.record("Could not read image dimensions")
            return (0, 0)
        }
        return (width, height)
    }
}
