import Foundation

/// Compact `[Float]` ↔ `Data` codec used for the `Entry.embedding` blob.
/// Layout: 1-byte version, 4-byte little-endian count, `count * 4` bytes
/// of little-endian float payload. Apple ARM64 + x86_64 are both
/// little-endian, so we write the in-memory representation directly.
public enum EmbeddingCodec {
    static let version: UInt8 = 1
    static let headerBytes = 5

    public static func encode(_ vector: [Float]) -> Data {
        var data = Data()
        data.reserveCapacity(headerBytes + vector.count * MemoryLayout<Float>.size)
        data.append(version)
        var count = UInt32(vector.count).littleEndian
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        vector.withUnsafeBufferPointer { buffer in
            if let base = buffer.baseAddress {
                data.append(UnsafeBufferPointer(start: base, count: buffer.count))
            }
        }
        return data
    }

    public static func decode(_ data: Data) -> [Float]? {
        guard data.count >= headerBytes, data[data.startIndex] == version else { return nil }
        let countData = data.subdata(in: data.startIndex.advanced(by: 1)..<data.startIndex.advanced(by: headerBytes))
        let count = countData.withUnsafeBytes { UInt32(littleEndian: $0.load(as: UInt32.self)) }
        let expectedSize = headerBytes + Int(count) * MemoryLayout<Float>.size
        guard data.count == expectedSize else { return nil }
        let payload = data.subdata(in: data.startIndex.advanced(by: headerBytes)..<data.endIndex)
        return payload.withUnsafeBytes { buffer in
            let pointer = buffer.bindMemory(to: Float.self)
            return Array(UnsafeBufferPointer(start: pointer.baseAddress, count: Int(count)))
        }
    }
}

private extension Data {
    mutating func append<T>(_ buffer: UnsafeBufferPointer<T>) {
        let raw = UnsafeRawBufferPointer(buffer)
        append(contentsOf: raw)
    }
}
