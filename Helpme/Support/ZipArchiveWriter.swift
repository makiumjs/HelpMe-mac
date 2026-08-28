import Foundation
import Compression

/// Scrittore di archivi ZIP in-process, senza dipendenze esterne.
///
/// Sostituisce il lancio di `/usr/bin/zip` via `Process`, che non è
/// disponibile su iPadOS e viene bloccato dall'App Sandbox su macOS.
/// Produce archivi conformi a PKZIP (metodo deflate, fallback stored),
/// che è quanto serve per confezionare un pacchetto OpenXML `.docx`.
nonisolated struct ZipArchiveWriter {

    private struct Entry {
        let path: String
        let data: Data
        let compressed: Data
        let method: UInt16      // 0 = stored, 8 = deflate
        let crc: UInt32
        var localHeaderOffset: UInt32 = 0
    }

    private var entries: [Entry] = []

    init() {}

    /// Aggiunge un file all'archivio. L'ordine di inserimento è preservato:
    /// per un `.docx` `[Content_Types].xml` va aggiunto per primo.
    mutating func addFile(path: String, contents: Data) {
        let crc = ZipArchiveWriter.crc32(contents)
        let deflated = ZipArchiveWriter.deflate(contents)

        // Usa la compressione solo se conviene davvero.
        if let deflated, deflated.count < contents.count {
            entries.append(Entry(path: path, data: contents, compressed: deflated, method: 8, crc: crc))
        } else {
            entries.append(Entry(path: path, data: contents, compressed: contents, method: 0, crc: crc))
        }
    }

    mutating func addFile(path: String, text: String) {
        addFile(path: path, contents: Data(text.utf8))
    }

    /// Serializza l'archivio completo.
    func makeArchive(modifiedAt date: Date = Date()) -> Data {
        var output = Data()
        var placed: [Entry] = []
        let (dosTime, dosDate) = ZipArchiveWriter.dosTimestamp(from: date)

        // 1. Local file header + dati, per ogni entry.
        for var entry in entries {
            entry.localHeaderOffset = UInt32(output.count)
            let nameBytes = Data(entry.path.utf8)

            output.appendUInt32(0x04034B50)                  // firma local header
            output.appendUInt16(20)                          // versione necessaria
            output.appendUInt16(0)                           // flag
            output.appendUInt16(entry.method)
            output.appendUInt16(dosTime)
            output.appendUInt16(dosDate)
            output.appendUInt32(entry.crc)
            output.appendUInt32(UInt32(entry.compressed.count))
            output.appendUInt32(UInt32(entry.data.count))
            output.appendUInt16(UInt16(nameBytes.count))
            output.appendUInt16(0)                           // extra field
            output.append(nameBytes)
            output.append(entry.compressed)

            placed.append(entry)
        }

        // 2. Central directory.
        let centralDirectoryOffset = UInt32(output.count)
        for entry in placed {
            let nameBytes = Data(entry.path.utf8)

            output.appendUInt32(0x02014B50)                  // firma central directory
            output.appendUInt16(20)                          // versione di creazione
            output.appendUInt16(20)                          // versione necessaria
            output.appendUInt16(0)                           // flag
            output.appendUInt16(entry.method)
            output.appendUInt16(dosTime)
            output.appendUInt16(dosDate)
            output.appendUInt32(entry.crc)
            output.appendUInt32(UInt32(entry.compressed.count))
            output.appendUInt32(UInt32(entry.data.count))
            output.appendUInt16(UInt16(nameBytes.count))
            output.appendUInt16(0)                           // extra field
            output.appendUInt16(0)                           // commento
            output.appendUInt16(0)                           // disco iniziale
            output.appendUInt16(0)                           // attributi interni
            output.appendUInt32(0)                           // attributi esterni
            output.appendUInt32(entry.localHeaderOffset)
            output.append(nameBytes)
        }
        let centralDirectorySize = UInt32(output.count) - centralDirectoryOffset

        // 3. End of central directory.
        output.appendUInt32(0x06054B50)
        output.appendUInt16(0)                               // numero disco
        output.appendUInt16(0)                               // disco con la central directory
        output.appendUInt16(UInt16(placed.count))
        output.appendUInt16(UInt16(placed.count))
        output.appendUInt32(centralDirectorySize)
        output.appendUInt32(centralDirectoryOffset)
        output.appendUInt16(0)                               // commento archivio

        return output
    }

    func write(to url: URL, modifiedAt date: Date = Date()) throws {
        try makeArchive(modifiedAt: date).write(to: url, options: .atomic)
    }

    // MARK: - Deflate

    /// `COMPRESSION_ZLIB` di Apple produce DEFLATE grezzo, che è esattamente
    /// il metodo 8 previsto da ZIP.
    private static func deflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }

        // Margine per il caso peggiore, in cui il deflate espande i dati.
        let capacity = data.count + (data.count / 2) + 64
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { destination.deallocate() }

        let written = data.withUnsafeBytes { raw -> Int in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_encode_buffer(destination, capacity, base, data.count, nil, COMPRESSION_ZLIB)
        }

        guard written > 0 else { return nil }
        return Data(bytes: destination, count: written)
    }

    // MARK: - CRC32

    private static let crcTable: [UInt32] = {
        (0..<256).map { index -> UInt32 in
            var value = UInt32(index)
            for _ in 0..<8 {
                value = (value & 1 == 1) ? (0xEDB88320 ^ (value >> 1)) : (value >> 1)
            }
            return value
        }
    }()

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }

    // MARK: - Data e ora in formato MS-DOS

    private static func dosTimestamp(from date: Date) -> (time: UInt16, date: UInt16) {
        let parts = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        let year = max(1980, parts.year ?? 1980)
        let dosDate = UInt16(((year - 1980) << 9) | ((parts.month ?? 1) << 5) | (parts.day ?? 1))
        let dosTime = UInt16(((parts.hour ?? 0) << 11) | ((parts.minute ?? 0) << 5) | ((parts.second ?? 0) / 2))
        return (dosTime, dosDate)
    }
}

// MARK: - Scrittura little-endian

private nonisolated extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
