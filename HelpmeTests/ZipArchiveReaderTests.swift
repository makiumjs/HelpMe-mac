import XCTest
@testable import Helpme

/// Il lettore ZIP è il fondamento di DOCX ed EPUB: se sbaglia un offset,
/// i due formati si aprono su testo spazzatura invece di fallire.
final class ZipArchiveReaderTests: XCTestCase {

    // MARK: - Andata e ritorno con lo scrittore

    func testRoundTripSingleTextFile() throws {
        let content = "Il pistone scende e aspira la miscela aria-carburante."

        var writer = ZipArchiveWriter()
        writer.addFile(path: "word/document.xml", text: content)

        let reader = try ZipArchiveReader(data: writer.makeArchive())
        XCTAssertEqual(reader.paths, ["word/document.xml"])
        XCTAssertEqual(try reader.text(for: "word/document.xml"), content)
    }

    /// Un testo lungo e ripetitivo viene compresso (metodo 8): è il caso in
    /// cui serve davvero l'inflate, non il semplice ricopiare i byte.
    func testRoundTripDeflatedContent() throws {
        let content = String(repeating: "La fotosintesi clorofilliana trasforma la luce in energia chimica. ", count: 200)

        var writer = ZipArchiveWriter()
        writer.addFile(path: "capitolo.txt", text: content)
        let archive = writer.makeArchive()

        XCTAssertLessThan(archive.count, content.utf8.count / 2, "Il contenuto ripetitivo doveva essere compresso")

        let reader = try ZipArchiveReader(data: archive)
        XCTAssertEqual(try reader.text(for: "capitolo.txt"), content)
    }

    func testRoundTripPreservesOrderAndAllEntries() throws {
        var writer = ZipArchiveWriter()
        writer.addFile(path: "[Content_Types].xml", text: "<Types/>")
        writer.addFile(path: "_rels/.rels", text: "<Relationships/>")
        writer.addFile(path: "word/document.xml", text: "<w:document/>")

        let reader = try ZipArchiveReader(data: writer.makeArchive())
        XCTAssertEqual(reader.paths, ["[Content_Types].xml", "_rels/.rels", "word/document.xml"])
        XCTAssertTrue(reader.contains("word/document.xml"))
        XCTAssertFalse(reader.contains("word/styles.xml"))
    }

    func testEmptyFileRoundTrips() throws {
        var writer = ZipArchiveWriter()
        writer.addFile(path: "vuoto.txt", text: "")
        writer.addFile(path: "pieno.txt", text: "contenuto")

        let reader = try ZipArchiveReader(data: writer.makeArchive())
        XCTAssertEqual(try reader.text(for: "vuoto.txt"), "")
        XCTAssertEqual(try reader.text(for: "pieno.txt"), "contenuto")
    }

    func testUnicodeContentSurvivesRoundTrip() throws {
        let content = "Perché è così? L'àncora, l'ù, il caffè — «virgolette» e 20 °C."

        var writer = ZipArchiveWriter()
        writer.addFile(path: "accenti.txt", text: content)

        let reader = try ZipArchiveReader(data: writer.makeArchive())
        XCTAssertEqual(try reader.text(for: "accenti.txt"), content)
    }

    // MARK: - Errori

    func testNonZipDataIsRejected() {
        let notAZip = Data("Questo è solo del testo, non un archivio.".utf8)
        XCTAssertThrowsError(try ZipArchiveReader(data: notAZip)) { error in
            XCTAssertEqual(error as? ZipArchiveReader.ReadError, .notAZipArchive)
        }
    }

    func testMissingEntryIsReportedByName() throws {
        var writer = ZipArchiveWriter()
        writer.addFile(path: "presente.txt", text: "ok")
        let reader = try ZipArchiveReader(data: writer.makeArchive())

        XCTAssertThrowsError(try reader.data(for: "assente.txt")) { error in
            XCTAssertEqual(error as? ZipArchiveReader.ReadError, .entryNotFound("assente.txt"))
            // Il messaggio deve nominare la parte mancante, non essere generico.
            XCTAssertTrue(error.localizedDescription.contains("assente.txt"))
        }
    }

    /// Se un byte del contenuto cambia, il CRC non torna: meglio un errore
    /// esplicito che indicizzare testo corrotto senza accorgersene.
    func testCorruptedPayloadFailsChecksum() throws {
        var writer = ZipArchiveWriter()
        writer.addFile(path: "dati.txt", text: "contenuto originale da non alterare")
        var archive = writer.makeArchive()

        // Il payload sta subito dopo l'header locale (30 byte + nome).
        let payloadStart = 30 + "dati.txt".utf8.count
        archive[payloadStart] = archive[payloadStart] ^ 0xFF

        let reader = try ZipArchiveReader(data: archive)
        XCTAssertThrowsError(try reader.data(for: "dati.txt")) { error in
            guard let readError = error as? ZipArchiveReader.ReadError else {
                return XCTFail("Atteso un ReadError, ricevuto \(error)")
            }
            // Stored o deflate, il byte alterato va comunque intercettato.
            XCTAssertTrue(
                readError == .checksumMismatch("dati.txt") || readError == .inflateFailed("dati.txt"),
                "Atteso un errore di integrità, ricevuto \(readError)"
            )
        }
    }

    func testTruncatedArchiveIsRejected() throws {
        var writer = ZipArchiveWriter()
        writer.addFile(path: "dati.txt", text: "contenuto")
        let archive = writer.makeArchive()

        // Tolta la coda, l'End Of Central Directory non c'è più.
        let truncated = archive.prefix(archive.count - 10)
        XCTAssertThrowsError(try ZipArchiveReader(data: Data(truncated)))
    }
}
