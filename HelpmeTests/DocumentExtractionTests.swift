import XCTest
import PDFKit
import AppKit
@testable import Helpme

/// AC2: DOCX ed EPUB si leggono davvero.
///
/// Il criterio non è "non lancia un errore" ma "restituisce le parole del
/// documento senza il markup": indicizzare tag XML è peggio di non
/// indicizzare niente, perché sporca in silenzio il contesto del prompt.
@MainActor
final class DocumentExtractionTests: XCTestCase {

    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("HelpmeDocTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - DOCX

    /// Il giro completo: l'app esporta un .docx e lo sa rileggere.
    func testExtractsTextFromDocxProducedByTheApp() throws {
        let student = StudentProfile(
            name: "Marco Rossi",
            classInfo: "3ª A Agrario",
            programType: .minimi,
            interest: "Meccanica agraria"
        )
        let data = DocxExportService().makeDocxData(
            schoolInfo: SchoolInfo(),
            student: student,
            format: .clearExplanation,
            title: "Il ciclo a quattro tempi",
            content: """
            Il **pistone** scende e aspira la miscela.
            Poi risale e la comprime.
            """
        )

        let url = scratch.appendingPathComponent("lezione.docx")
        try data.write(to: url)

        let text = try DocumentIndexer().extractText(from: url)

        XCTAssertTrue(text.contains("pistone"), "Testo estratto: \(text)")
        XCTAssertTrue(text.contains("comprime"))
        XCTAssertTrue(text.contains("Il ciclo a quattro tempi"))

        // Nessun residuo di markup né di markdown.
        XCTAssertFalse(text.contains("<w:"), "Il markup OOXML non deve finire nell'indice")
        XCTAssertFalse(text.contains("xml:space"))
        XCTAssertFalse(text.contains("**"), "Gli asterischi markdown non devono comparire")
    }

    func testDocxParagraphsBecomeSeparateLines() {
        let xml = """
        <w:document><w:body>
        <w:p><w:r><w:t>Prima riga</w:t></w:r></w:p>
        <w:p><w:r><w:t>Seconda riga</w:t></w:r></w:p>
        </w:body></w:document>
        """
        let text = MarkupTextExtractor.textFromWordDocument(xml)
        XCTAssertEqual(text, "Prima riga\nSeconda riga")
    }

    /// Una tabella deve restare leggibile per righe: appiattirla su una
    /// riga sola renderebbe illeggibile la griglia di valutazione.
    func testDocxTableRowsAreSeparated() {
        let xml = """
        <w:tbl>
        <w:tr><w:tc><w:p><w:r><w:t>Indicatore</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Punteggio</w:t></w:r></w:p></w:tc></w:tr>
        <w:tr><w:tc><w:p><w:r><w:t>Comprensione</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Buono</w:t></w:r></w:p></w:tc></w:tr>
        </w:tbl>
        """
        let lines = MarkupTextExtractor.textFromWordDocument(xml).components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2, "Attese due righe di tabella, ottenuto: \(lines)")
        XCTAssertTrue(lines[0].contains("Indicatore") && lines[0].contains("Punteggio"))
        XCTAssertTrue(lines[1].contains("Comprensione") && lines[1].contains("Buono"))
    }

    func testDocxDecodesXmlEntities() {
        let xml = "<w:p><w:r><w:t>Perch&#233; l&apos;acqua &amp; l&#x27;aria</w:t></w:r></w:p>"
        XCTAssertEqual(MarkupTextExtractor.textFromWordDocument(xml), "Perché l'acqua & l'aria")
    }

    func testDocxWithoutDocumentPartIsRejectedClearly() throws {
        var writer = ZipArchiveWriter()
        writer.addFile(path: "qualcosa/altro.xml", text: "<vuoto/>")
        let url = scratch.appendingPathComponent("finto.docx")
        try writer.write(to: url)

        XCTAssertThrowsError(try DocumentIndexer().extractText(from: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("finto.docx"))
            XCTAssertTrue(error.localizedDescription.lowercased().contains("word"))
        }
    }

    // MARK: - EPUB

    func testExtractsEpubChaptersInSpineOrder() throws {
        let url = scratch.appendingPathComponent("libro.epub")
        try makeEpub(at: url)

        let text = try DocumentIndexer().extractText(from: url)

        XCTAssertTrue(text.contains("La radice assorbe l'acqua"), "Testo: \(text)")
        XCTAssertTrue(text.contains("La foglia cattura la luce"))
        XCTAssertFalse(text.contains("<p>"), "L'HTML non deve finire nell'indice")
        XCTAssertFalse(text.contains("color: red"), "Il CSS non è contenuto del libro")

        // Lo spine impone capitolo 1 prima del 2, anche se i nomi dei file
        // in ordine alfabetico direbbero il contrario.
        let radice = try XCTUnwrap(text.range(of: "La radice assorbe"))
        let foglia = try XCTUnwrap(text.range(of: "La foglia cattura"))
        XCTAssertLessThan(radice.lowerBound, foglia.lowerBound)
    }

    func testHtmlBlockTagsBecomeLineBreaks() {
        let html = "<html><body><h1>Titolo</h1><p>Primo capoverso.</p><p>Secondo capoverso.</p></body></html>"
        let lines = MarkupTextExtractor.textFromHtml(html).components(separatedBy: "\n")
        XCTAssertEqual(lines, ["Titolo", "Primo capoverso.", "Secondo capoverso."])
    }

    /// Senza uno spazio al posto dei tag inline, "<b>ciclo</b>termico"
    /// diventerebbe una parola sola che nessuna ricerca troverebbe.
    func testInlineTagsDoNotGlueWordsTogether() {
        let text = MarkupTextExtractor.textFromHtml("<p>Il <b>ciclo</b> <i>termico</i> del motore</p>")
        XCTAssertEqual(text, "Il ciclo termico del motore")
    }

    func testScriptAndStyleAreDropped() {
        let html = """
        <html><head><style>p { color: red; }</style></head>
        <body><script>var x = "non è testo";</script><p>Solo questo conta.</p></body></html>
        """
        XCTAssertEqual(MarkupTextExtractor.textFromHtml(html), "Solo questo conta.")
    }

    // MARK: - PDF

    /// Il PDF è il formato che un docente importa più spesso — le verifiche
    /// e le dispense circolano così. Era l'unico dei formati dichiarati
    /// senza una prova su un file vero.
    func testExtractsTextFromRealPdf() throws {
        let url = scratch.appendingPathComponent("dispensa.pdf")
        try makePdf(at: url, pages: [
            "Il motore a quattro tempi compie un ciclo completo in due giri dell'albero.",
            "Nelle macchine agricole la manutenzione dei filtri previene l'usura."
        ])

        let text = try DocumentIndexer().extractText(from: url)

        XCTAssertTrue(text.contains("quattro tempi"), "Testo estratto: \(text)")
        XCTAssertTrue(text.contains("manutenzione dei filtri"))
    }

    /// L'estrattore numera le pagine: su una dispensa lunga serve a capire
    /// da dove viene un frammento recuperato dalla ricerca.
    func testPdfPagesAreNumbered() throws {
        let url = scratch.appendingPathComponent("due-pagine.pdf")
        try makePdf(at: url, pages: ["Prima pagina.", "Seconda pagina."])

        let text = try DocumentIndexer().extractText(from: url)
        XCTAssertTrue(text.contains("[Pagina 1]"), "Testo: \(text)")
        XCTAssertTrue(text.contains("[Pagina 2]"))
    }

    /// Una scansione non ha testo selezionabile: l'errore deve dirlo, e
    /// nominare l'OCR, invece di un generico "impossibile leggere".
    func testPdfWithoutSelectableTextSuggestsOcr() throws {
        let url = scratch.appendingPathComponent("scansione.pdf")
        try makeImageOnlyPdf(at: url)

        XCTAssertThrowsError(try DocumentIndexer().extractText(from: url)) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("scansione.pdf"), "Messaggio: \(message)")
            XCTAssertTrue(message.lowercased().contains("ocr"),
                          "Il docente deve sapere che serve un riconoscimento OCR: \(message)")
        }
    }

    func testCorruptedPdfIsRejectedByName() throws {
        let url = scratch.appendingPathComponent("rotto.pdf")
        try Data("non è affatto un PDF".utf8).write(to: url)

        XCTAssertThrowsError(try DocumentIndexer().extractText(from: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("rotto.pdf"))
        }
    }

    // MARK: - Formati e codifiche

    func testUnsupportedFormatNamesTheExtensionAndTheAlternatives() throws {
        let url = scratch.appendingPathComponent("foglio.numbers")
        try Data("x".utf8).write(to: url)

        XCTAssertThrowsError(try DocumentIndexer().extractText(from: url)) { error in
            let message = error.localizedDescription
            XCTAssertTrue(message.contains(".numbers"), "Messaggio: \(message)")
            XCTAssertTrue(message.contains(".docx") && message.contains(".epub"),
                          "Il messaggio deve elencare i formati leggibili: \(message)")
        }
    }

    func testSupportedExtensionsCoverDocxAndEpub() {
        XCTAssertTrue(DocumentIndexer.supportedExtensions.contains("docx"))
        XCTAssertTrue(DocumentIndexer.supportedExtensions.contains("epub"))
    }

    /// Un file salvato da un vecchio PC di scuola non è UTF-8: rifiutarlo
    /// per un accento sarebbe un errore evitabile.
    func testPlainTextFallsBackToLegacyEncoding() throws {
        let url = scratch.appendingPathComponent("appunti.txt")
        let latin1 = try XCTUnwrap("Perché è così".data(using: .isoLatin1))
        try latin1.write(to: url)

        let text = try DocumentIndexer().extractText(from: url)
        XCTAssertTrue(text.contains("Perch"), "Testo: \(text)")
        XCTAssertFalse(text.isEmpty)
    }

    // MARK: - Helper

    /// Genera un PDF con testo selezionabile, una pagina per stringa.
    /// Costruito qui invece di allegare un file: un fixture binario nel
    /// repository non si può ispezionare in una revisione.
    private func makePdf(at url: URL, pages: [String]) throws {
        let pdf = PDFDocument()

        for (index, content) in pages.enumerated() {
            let text = NSAttributedString(
                string: content,
                attributes: [.font: NSFont.systemFont(ofSize: 14)]
            )
            let data = NSMutableData()
            let consumer = CGDataConsumer(data: data as CFMutableData)!
            var box = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4 in punti
            let context = CGContext(consumer: consumer, mediaBox: &box, nil)!

            context.beginPDFPage(nil)
            let graphics = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            text.draw(in: CGRect(x: 50, y: 700, width: 495, height: 100))
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
            context.closePDF()

            guard let onePage = PDFDocument(data: data as Data), let page = onePage.page(at: 0) else {
                throw XCTSkip("Impossibile costruire la pagina PDF di prova")
            }
            pdf.insert(page, at: index)
        }

        guard pdf.write(to: url) else {
            throw XCTSkip("Impossibile scrivere il PDF di prova")
        }
    }

    /// Un PDF con una pagina disegnata ma senza testo: è ciò che produce
    /// uno scanner, e ciò su cui l'app deve chiedere un OCR.
    private func makeImageOnlyPdf(at url: URL) throws {
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let context = CGContext(consumer: consumer, mediaBox: &box, nil)!

        context.beginPDFPage(nil)
        context.setFillColor(NSColor.lightGray.cgColor)
        context.fill(CGRect(x: 100, y: 400, width: 300, height: 200))
        context.endPDFPage()
        context.closePDF()

        try (data as Data).write(to: url)
    }

    /// Costruisce un EPUB minimo ma conforme: container, OPF con manifest e
    /// spine, e due capitoli il cui ordine alfabetico è opposto allo spine.
    private func makeEpub(at url: URL) throws {
        var writer = ZipArchiveWriter()
        writer.addFile(path: "mimetype", text: "application/epub+zip")
        writer.addFile(path: "META-INF/container.xml", text: """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
        </container>
        """)
        writer.addFile(path: "OEBPS/content.opf", text: """
        <?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <manifest>
            <item id="cap1" href="zeta-radice.xhtml" media-type="application/xhtml+xml"/>
            <item id="cap2" href="alfa-foglia.xhtml" media-type="application/xhtml+xml"/>
            <item id="css" href="stile.css" media-type="text/css"/>
          </manifest>
          <spine>
            <itemref idref="cap1"/>
            <itemref idref="cap2"/>
          </spine>
        </package>
        """)
        writer.addFile(path: "OEBPS/zeta-radice.xhtml", text: """
        <html><head><style>p { color: red; }</style></head>
        <body><h1>La radice</h1><p>La radice assorbe l'acqua dal terreno.</p></body></html>
        """)
        writer.addFile(path: "OEBPS/alfa-foglia.xhtml", text: """
        <html><body><h1>La foglia</h1><p>La foglia cattura la luce del sole.</p></body></html>
        """)
        writer.addFile(path: "OEBPS/stile.css", text: "p { color: red; }")
        try writer.write(to: url)
    }
}
