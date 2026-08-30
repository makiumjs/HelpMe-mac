import Foundation
import Compression
nonisolated struct ZipArchiveReader {

    struct Entry {
        let path: String
        let method: UInt16
        let crc: UInt32
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    enum ReadError: LocalizedError, Equatable {
        case notAZipArchive
        case corruptedCentralDirectory
        case entryNotFound(String)
        case unsupportedCompression(UInt16)
        case inflateFailed(String)
        case checksumMismatch(String)

        var errorDescription: String? {
            switch self {
            case .notAZipArchive:
                return "Il file non è un archivio ZIP valido: manca la firma di fine archivio."
            case .corruptedCentralDirectory:
                return "L'indice interno dell'archivio è danneggiato o incompleto."
            case .entryNotFound(let path):
                return "L'archivio non contiene la parte richiesta (\(path))."
            case .unsupportedCompression(let method):
                return "Metodo di compressione \(method) non supportato: sono gestiti solo 'stored' e 'deflate'."
            case .inflateFailed(let path):
                return "Impossibile decomprimere \(path): i dati sono danneggiati."
            case .checksumMismatch(let path):
                return "Il controllo di integrità di \(path) è fallito: il file è corrotto."
            }
        }
    }

    private let bytes: [UInt8]
    let entries: [Entry]

    // MARK: - Apertura

    init(data: Data) throws {
        self.bytes = [UInt8](data)
        self.entries = try ZipArchiveReader.readCentralDirectory(in: bytes)
    }

    init(contentsOf url: URL) throws {
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    var paths: [String] { entries.map(\.path) }

    func contains(_ path: String) -> Bool {
        entries.contains { $0.path == path }
    }

    // MARK: - Estrazione

    func data(for path: String) throws -> Data {
        guard let entry = entries.first(where: { $0.path == path }) else {
            throw ReadError.entryNotFound(path)
        }
        return try data(for: entry)
    }
    func text(for path: String) throws -> String {
        let raw = try data(for: path)
        if let utf8 = String(data: raw, encoding: .utf8) { return utf8 }
        return String(decoding: raw, as: UTF8.self)
    }

    func data(for entry: Entry) throws -> Data {
        guard entry.uncompressedSize > 0 else { return Data() }
        let header = entry.localHeaderOffset
        guard header >= 0, header + 30 <= bytes.count,
              readUInt32(at: header) == 0x04034B50 else {
            throw ReadError.corruptedCentralDirectory
        }
        let nameLength = Int(readUInt16(at: header + 26))
        let extraLength = Int(readUInt16(at: header + 28))
        let start = header + 30 + nameLength + extraLength
        let end = start + entry.compressedSize

        guard start >= 0, end <= bytes.count, start <= end else {
            throw ReadError.corruptedCentralDirectory
        }
        let payload = Array(bytes[start..<end])
        let output: Data
        switch entry.method {
        case 0:
            output = Data(payload)
        case 8:
            guard let inflated = ZipArchiveReader.inflate(payload, expectedSize: entry.uncompressedSize) else {
                throw ReadError.inflateFailed(entry.path)
            }
            output = inflated
        default:
            throw ReadError.unsupportedCompression(entry.method)
        }
        guard ZipArchiveWriter.crc32(output) == entry.crc else {
            throw ReadError.checksumMismatch(entry.path)
        }
        return output
    }

    // MARK: - Central directory

    private static func readCentralDirectory(in bytes: [UInt8]) throws -> [Entry] {
        guard bytes.count >= 22 else { throw ReadError.notAZipArchive }
        let searchFloor = max(0, bytes.count - 22 - 65_535)
        var eocd = -1
        var cursor = bytes.count - 22
        while cursor >= searchFloor {
            if bytes[cursor] == 0x50, bytes[cursor + 1] == 0x4B,
               bytes[cursor + 2] == 0x05, bytes[cursor + 3] == 0x06 {
                eocd = cursor
                break
            }
            cursor -= 1
        }
        guard eocd >= 0 else { throw ReadError.notAZipArchive }

        func u16(_ offset: Int) -> UInt16 {
            UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
        }
        func u32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8)
                | (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
        }
        let count = Int(u16(eocd + 10))
        let directorySize = Int(u32(eocd + 12))
        let directoryOffset = Int(u32(eocd + 16))
        guard directoryOffset >= 0,
              directorySize >= 0,
              directoryOffset + directorySize <= bytes.count else {
            throw ReadError.corruptedCentralDirectory
        }
        var result: [Entry] = []
        result.reserveCapacity(count)
        var offset = directoryOffset
        for _ in 0..<count {
            guard offset + 46 <= bytes.count, u32(offset) == 0x02014B50 else {
                throw ReadError.corruptedCentralDirectory
            }

            let method = u16(offset + 10)
            let crc = u32(offset + 16)
            let compressedSize = Int(u32(offset + 20))
            let uncompressedSize = Int(u32(offset + 24))
            let nameLength = Int(u16(offset + 28))
            let extraLength = Int(u16(offset + 30))
            let commentLength = Int(u16(offset + 32))
            let localHeaderOffset = Int(u32(offset + 42))
            let nameStart = offset + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= bytes.count else { throw ReadError.corruptedCentralDirectory }
            let path = String(decoding: bytes[nameStart..<nameEnd], as: UTF8.self)
            if !path.hasSuffix("/") {
                result.append(Entry(
                    path: path,
                    method: method,
                    crc: crc,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                ))
            }
            offset = nameEnd + extraLength + commentLength
        }
        return result
    }
    // MARK: - Inflate
    private static func inflate(_ payload: [UInt8], expectedSize: Int) -> Data? {
        guard !payload.isEmpty, expectedSize > 0 else { return nil }
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedSize)
        defer { destination.deallocate() }
        let written = payload.withUnsafeBufferPointer { buffer -> Int in
            guard let base = buffer.baseAddress else { return 0 }
            return compression_decode_buffer(
                destination, expectedSize,
                base, payload.count,
                nil, COMPRESSION_ZLIB
            )
        }
        guard written == expectedSize else { return nil }
        return Data(bytes: destination, count: written)
    }

    // MARK: - Letture little-endian
    private func readUInt16(at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }
    private func readUInt32(at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
    }
}
