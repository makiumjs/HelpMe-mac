import XCTest
@testable import Helpme

@MainActor
final class DocxExportTests: XCTestCase {

    private let school = SchoolInfo(
        instituteName: "I.I.S. Antonio Della Lucia Feltre",
        subTypes: "Agrario",
        mechanographicCode: "BLIS009002",
        address: "Via Vellai 41",
        schoolYear: "A.S. 2025/2026",
        teacherName: "Prof. Sostegno"
    )

    private func student() -> StudentProfile {
        StudentProfile(name: "Marco Rossi", classInfo: "3ª A Agrario", programType: .minimi, interest: "Meccanica")
    }

    private func documentXml(for content: String) -> String {
        let data = DocxExportService().makeDocxData(
            schoolInfo: school,
            student: student(),
            format: .equipollenteExam,
            title: "Verifica Equipollente",
            content: content
        )
        // Il .docx è compresso: si controlla il markup rigenerandolo a parte.
        return MarkdownToOoxml.body(from: content) + String(decoding: data.prefix(4), as: UTF8.self)
    }

    func testDocxBundleCreation() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestVerification_\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: url) }

        try DocxExportService().createDocxBundle(
            schoolInfo: school,
            student: student(),
            format: .equipollenteExam,
            title: "Verifica Equipollente",
            content: "# Verifica\n\nDescrivi la fase di aspirazione.\n- Opzione A\n- Opzione B",
            destinationUrl: url
        )

        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(Array(data.prefix(2)), [0x50, 0x4B], "deve essere un archivio ZIP valido")
    }

    // MARK: - Il foglio consegnato allo studente non porta le risposte

    /// Il giro completo, dal materiale generato al file .docx vero: è il
    /// solo percorso che porta il contenuto fuori dall'app, su carta, in
    /// mano allo studente. Prima passava il testo grezzo e ci finivano
    /// stampate le soluzioni.
    func testExportedDocxDoesNotContainTheAnswerKey() throws {
        let quizMaterial = """
        ### Domanda 1
        Durante quale fase il pistone comprime la miscela?
        - [ ] Aspirazione :: no, in aspirazione il pistone scende
        - [x] Compressione :: esatto, il pistone risale con le valvole chiuse
        - [ ] Scoppio :: la candela accende la miscela
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuizHandout_\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: url) }

        try DocxExportService().createDocxBundle(
            schoolInfo: school,
            student: student(),
            format: .interactiveQuiz,
            title: "Quiz di Autoverifica",
            content: StudyTextPresenter.handout(quizMaterial),
            destinationUrl: url
        )

        // Si rilegge il documento vero dall'archivio, non il markup a parte.
        let archive = try ZipArchiveReader(contentsOf: url)
        let documentXml = try archive.text(for: "word/document.xml")

        XCTAssertFalse(documentXml.contains("[x]"), "marcatore della risposta esatta nel documento")
        XCTAssertFalse(documentXml.contains("esatto, il pistone risale"), "spiegazione della risposta nel documento")
        XCTAssertFalse(documentXml.contains("no, in aspirazione"))

        // Le domande e le alternative devono esserci: è pur sempre un quiz.
        XCTAssertTrue(documentXml.contains("Durante quale fase"))
        XCTAssertTrue(documentXml.contains("Compressione"))
        XCTAssertTrue(documentXml.contains("Aspirazione"))
    }

    /// Il docente la chiave di correzione la vuole: sta in coda, dopo
    /// un'interruzione di pagina, così gli basta non stampare l'ultima.
    func testExportedDocxCarriesTheAnswerKeyOnItsOwnPage() throws {
        let quizMaterial = """
        ### Domanda 1
        Durante quale fase il pistone comprime la miscela?
        - [ ] Aspirazione :: no, in aspirazione il pistone scende
        - [x] Compressione :: esatto, il pistone risale con le valvole chiuse
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuizConChiave_\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: url) }

        try DocxExportService().createDocxBundle(
            schoolInfo: school,
            student: student(),
            format: .interactiveQuiz,
            title: "Quiz di Autoverifica",
            content: StudyTextPresenter.handout(quizMaterial),
            destinationUrl: url,
            answerKey: StudyTextPresenter.answerKey(from: quizMaterial)
        )

        let archive = try ZipArchiveReader(contentsOf: url)
        let xml = try archive.text(for: "word/document.xml")

        XCTAssertTrue(xml.contains("Chiave di correzione"))
        XCTAssertTrue(xml.contains("w:br w:type=\"page\""), "la chiave deve stare su una pagina a sé")

        // La spiegazione della risposta deve stare DOPO l'interruzione di
        // pagina: nel foglio dello studente non ci va.
        let pageBreak = try XCTUnwrap(xml.range(of: "w:br w:type=\"page\""))
        let explanation = try XCTUnwrap(xml.range(of: "esatto, il pistone risale"))
        XCTAssertLessThan(pageBreak.lowerBound, explanation.lowerBound)
    }

    func testExportWithoutQuizHasNoAnswerKeyPage() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Spiegazione_\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: url) }

        let plain = "# Il motore\n\nIl pistone scende e aspira la miscela."
        try DocxExportService().createDocxBundle(
            schoolInfo: school,
            student: student(),
            format: .clearExplanation,
            title: "Spiegazione",
            content: StudyTextPresenter.handout(plain),
            destinationUrl: url,
            answerKey: StudyTextPresenter.answerKey(from: plain)
        )

        let archive = try ZipArchiveReader(contentsOf: url)
        let xml = try archive.text(for: "word/document.xml")

        XCTAssertFalse(xml.contains("w:br w:type=\"page\""), "nessun quiz: niente pagina in più")
        XCTAssertFalse(xml.contains("Chiave di correzione"))
    }

    func testAnswerKeyNamesTheCorrectOptionAndWarnsTheTeacher() throws {
        let key = try XCTUnwrap(StudyTextPresenter.answerKey(from: """
        ### Domanda 1
        Quante fasi ha il ciclo Otto?
        - [ ] Due :: no, sono di più
        - [x] Quattro :: aspirazione, compressione, scoppio e scarico
        """))

        XCTAssertTrue(key.contains("Quattro"))
        XCTAssertTrue(key.contains("aspirazione, compressione, scoppio e scarico"))
        XCTAssertTrue(key.lowercased().contains("docente"))
        XCTAssertTrue(key.lowercased().contains("non consegnare"))
    }

    func testAnswerKeyIsNilWithoutAQuiz() {
        XCTAssertNil(StudyTextPresenter.answerKey(from: "# Titolo\n\nSolo prosa."))
        XCTAssertNil(StudyTextPresenter.answerKey(from: ""))
    }

    /// Le opzioni restano punti elenco veri, non paragrafi sciolti.
    func testExportedQuizOptionsAreStillBullets() {
        let handout = StudyTextPresenter.handout("- [x] Compressione :: esatto")
        let xml = MarkdownToOoxml.body(from: handout)
        XCTAssertTrue(xml.contains("w:ind"), "l'opzione ha perso il rientro da elenco puntato")
    }

    // MARK: - Il markdown non deve finire letterale nel documento

    func testBoldBecomesRealWordFormatting() {
        let xml = MarkdownToOoxml.body(from: "Usa il **formulario** allegato")
        XCTAssertFalse(xml.contains("**"), "gli asterischi non devono comparire nel documento")
        XCTAssertTrue(xml.contains("<w:b/>"), "il grassetto deve diventare formattazione Word")
        XCTAssertTrue(xml.contains("formulario"))
    }

    func testMarkdownTableBecomesWordTable() {
        let markdown = """
        | Indicatore | Punteggio |
        |---|---|
        | Comprensione del testo | 0-3 |
        | Uso del formulario | 0-2 |
        """
        let xml = MarkdownToOoxml.body(from: markdown)

        XCTAssertTrue(xml.contains("<w:tbl>"), "la griglia di valutazione deve essere una tabella vera")
        XCTAssertTrue(xml.contains("<w:tblBorders>"), "senza bordi espliciti la griglia è invisibile")
        XCTAssertEqual(xml.components(separatedBy: "<w:tr>").count - 1, 3, "intestazione + due righe")
        XCTAssertFalse(xml.contains("|---|"), "la riga di separazione non deve finire nel testo")
        XCTAssertTrue(xml.contains("Comprensione del testo"))
    }

    func testTableHeaderRepeatsAcrossPages() {
        let xml = MarkdownToOoxml.body(from: "| A | B |\n|---|---|\n| 1 | 2 |")
        XCTAssertTrue(xml.contains("<w:tblHeader/>"))
    }

    func testEveryTextRunPreservesSpaces() {
        let xml = MarkdownToOoxml.body(from: "- Primo punto\n\nUn paragrafo **con grassetto**.")
        let openings = xml.components(separatedBy: "<w:t").count - 1
        let preserving = xml.components(separatedBy: "<w:t xml:space=\"preserve\">").count - 1
        XCTAssertEqual(openings, preserving, "ogni <w:t> deve avere xml:space=preserve")
    }

    func testHeadingsAreRecognized() {
        let xml = MarkdownToOoxml.body(from: "# Titolo\n## Sottotitolo")
        XCTAssertFalse(xml.contains("# Titolo"))
        XCTAssertTrue(xml.contains("Titolo"))
        XCTAssertTrue(xml.contains("Sottotitolo"))
        XCTAssertTrue(xml.contains("<w:keepNext/>"))
    }

    func testSchoolYearIsNotDuplicated() {
        let data = DocxExportService().makeDocxData(
            schoolInfo: school,
            student: student(),
            format: .equipollenteExam,
            title: "T",
            content: "Testo"
        )
        XCTAssertGreaterThan(data.count, 0)
        // "A.S. 2025/2026" contiene già il prefisso: il template non deve riaggiungerlo.
        let xml = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(xml.contains("A.S. A.S."))
    }

    // MARK: - Robustezza dell'XML

    func testControlCharactersAreStripped() {
        let dirty = "Testo con \u{0008} carattere di controllo"
        let escaped = MarkdownToOoxml.escape(dirty)
        XCTAssertFalse(escaped.unicodeScalars.contains { $0.value == 0x0008 })
        XCTAssertTrue(escaped.contains("carattere di controllo"))
    }

    func testAngleBracketsAndAmpersandsAreEscaped() {
        let xml = MarkdownToOoxml.body(from: "Confronta a < b & c > d")
        XCTAssertTrue(xml.contains("&lt;"))
        XCTAssertTrue(xml.contains("&amp;"))
        XCTAssertTrue(xml.contains("&gt;"))
    }

    func testInlineParserHandlesMixedEmphasis() {
        let segments = MarkdownToOoxml.parseInline("normale **grassetto** e *corsivo*")
        XCTAssertTrue(segments.contains { $0.text.contains("grassetto") && $0.bold })
        XCTAssertTrue(segments.contains { $0.text.contains("corsivo") && $0.italic })
        XCTAssertTrue(segments.contains { $0.text.contains("normale") && !$0.bold && !$0.italic })
    }

    func testUnderscoreInsideWordIsNotItalic() {
        let segments = MarkdownToOoxml.parseInline("la variabile nome_utente resta invariata")
        XCTAssertEqual(segments.count, 1)
        XCTAssertFalse(segments[0].italic)
        XCTAssertTrue(segments[0].text.contains("nome_utente"))
    }
}
