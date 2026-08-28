import XCTest
@testable import Helpme

/// Verifica lo scrittore ZIP che ha sostituito il lancio di `/usr/bin/zip`.
final class ZipArchiveWriterTests: XCTestCase {

    func testCrc32MatchesKnownValue() {
        // Valore CRC-32 canonico della stringa "123456789".
        XCTAssertEqual(ZipArchiveWriter.crc32(Data("123456789".utf8)), 0xCBF43926)
    }

    func testArchiveHasValidSignaturesAndEntryCount() {
        var archive = ZipArchiveWriter()
        archive.addFile(path: "[Content_Types].xml", text: "<Types/>")
        archive.addFile(path: "word/document.xml", text: String(repeating: "<w:p/>", count: 500))

        let data = archive.makeArchive()

        // Firma del primo local file header.
        XCTAssertEqual(Array(data.prefix(4)), [0x50, 0x4B, 0x03, 0x04])

        // End of central directory in coda, con due voci dichiarate.
        let eocd = data.suffix(22)
        XCTAssertEqual(Array(eocd.prefix(4)), [0x50, 0x4B, 0x05, 0x06])
        let entryCount = Int(eocd[eocd.startIndex + 10]) | (Int(eocd[eocd.startIndex + 11]) << 8)
        XCTAssertEqual(entryCount, 2)
    }

    func testRepeatedContentIsActuallyCompressed() {
        let repetitive = String(repeating: "verifica equipollente ", count: 400)
        var archive = ZipArchiveWriter()
        archive.addFile(path: "word/document.xml", text: repetitive)

        let archiveSize = archive.makeArchive().count
        XCTAssertLessThan(archiveSize, repetitive.utf8.count / 2,
                          "il contenuto ripetitivo dovrebbe comprimersi ampiamente")
    }

    func testEmptyFileIsStoredWithoutError() {
        var archive = ZipArchiveWriter()
        archive.addFile(path: "empty.xml", text: "")
        let data = archive.makeArchive()
        XCTAssertGreaterThan(data.count, 22)
        XCTAssertEqual(Array(data.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
    }

    /// Il .docx prodotto dall'export deve essere leggibile come archivio reale.
    func testExportedDocxIsReadableArchive() throws {
        let exporter = DocxExportService()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HelpmeTest_\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: url) }

        try exporter.createDocxBundle(
            schoolInfo: SchoolInfo(),
            student: StudentProfile(name: "Marco Rossi", classInfo: "3ª A Agrario"),
            format: .equipollenteExam,
            title: "Verifica Equipollente",
            content: "# Titolo\n\nUna riga di testo.\n- Un punto elenco",
            destinationUrl: url
        )

        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(4)), [0x50, 0x4B, 0x03, 0x04])

        // Le quattro parti OPC attese devono comparire nella central directory.
        let raw = String(decoding: data, as: UTF8.self)
        for part in ["[Content_Types].xml", "_rels/.rels", "word/_rels/document.xml.rels", "word/document.xml"] {
            XCTAssertTrue(raw.contains(part), "parte mancante nell'archivio: \(part)")
        }
    }
}
