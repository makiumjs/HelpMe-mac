import XCTest
@testable import Helpme

/// L'importazione porta il testo del documento nell'editor, dove il docente
/// lo vede e lo corregge prima di generare. Non esiste piu' un indice
/// nascosto: quello che finisce nel materiale e' quello che si legge qui.
@MainActor
final class DocumentImportTests: XCTestCase {

    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("HelpmeImportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func writeLesson(named name: String, body: String? = nil) throws -> URL {
        let url = scratch.appendingPathComponent(name)
        let text = body ?? """
        Il motore a quattro tempi compie aspirazione, compressione, scoppio e scarico.
        Nelle macchine agricole la manutenzione dei filtri previene l'usura dei cilindri.
        """
        try Data(text.utf8).write(to: url)
        return url
    }

    func testImportPutsTheDocumentTextInTheEditor() async throws {
        let viewModel = makeAppViewModel()

        await viewModel.importDocuments(urls: [try writeLesson(named: "meccanica.txt")])

        XCTAssertTrue(viewModel.sourceText.contains("quattro tempi"), viewModel.sourceText)
        XCTAssertFalse(viewModel.isImportingDocuments)
        XCTAssertNil(viewModel.errorMessage)
        let status = try XCTUnwrap(viewModel.statusMessage)
        XCTAssertTrue(status.contains("meccanica"), "Stato: \(status)")
    }

    /// Importare non deve cancellare quello che il docente aveva gia' scritto:
    /// perderebbe il lavoro senza chiedere.
    func testImportAppendsInsteadOfOverwritingTheEditor() async throws {
        let viewModel = makeAppViewModel()
        viewModel.sourceText = "Appunti presi a lezione."

        await viewModel.importDocuments(urls: [try writeLesson(named: "meccanica.txt")])

        XCTAssertTrue(viewModel.sourceText.hasPrefix("Appunti presi a lezione."), viewModel.sourceText)
        XCTAssertTrue(viewModel.sourceText.contains("quattro tempi"), viewModel.sourceText)
    }

    func testImportingSeveralFilesKeepsThemApartWithTheirTitles() async throws {
        let viewModel = makeAppViewModel()
        let uno = try writeLesson(named: "meccanica.txt")
        let due = try writeLesson(named: "botanica.txt", body: """
        La fotosintesi trasforma la luce solare in energia chimica dentro le foglie.
        """)

        await viewModel.importDocuments(urls: [uno, due])

        XCTAssertTrue(viewModel.sourceText.contains("## meccanica"), viewModel.sourceText)
        XCTAssertTrue(viewModel.sourceText.contains("## botanica"), viewModel.sourceText)
        XCTAssertTrue(viewModel.sourceText.contains("fotosintesi"), viewModel.sourceText)
    }

    /// Un file scartato viene detto per nome. Ingoiarlo in silenzio farebbe
    /// credere al docente che quel materiale sia nell'editor.
    func testImportSurfacesFailuresWithTheFileName() async throws {
        let viewModel = makeAppViewModel()
        let bad = scratch.appendingPathComponent("slide.key")
        try Data("x".utf8).write(to: bad)

        await viewModel.importDocuments(urls: [bad])

        XCTAssertTrue(viewModel.sourceText.isEmpty)
        let error = try XCTUnwrap(viewModel.errorMessage)
        XCTAssertTrue(error.contains("slide.key"), "Errore: \(error)")
    }

    func testPartialImportReportsBothSidesSeparately() async throws {
        let viewModel = makeAppViewModel()
        let good = try writeLesson(named: "meccanica.txt")
        let bad = scratch.appendingPathComponent("slide.key")
        try Data("x".utf8).write(to: bad)

        await viewModel.importDocuments(urls: [good, bad])

        XCTAssertTrue(viewModel.sourceText.contains("quattro tempi"))
        XCTAssertNotNil(viewModel.statusMessage, "Il successo parziale va comunque riportato")
        XCTAssertNotNil(viewModel.errorMessage, "Il fallimento parziale va comunque riportato")
    }

    /// L'editor ha un limite: un PDF enorme non deve riempirlo fino a
    /// impallare la scrittura.
    func testTheEditorLimitIsHonoured() async throws {
        let viewModel = makeAppViewModel()
        let enorme = String(repeating: "Il trattore ara il campo. ", count: 6_000)

        await viewModel.importDocuments(urls: [try writeLesson(named: "lungo.txt", body: enorme)])

        XCTAssertGreaterThan(viewModel.sourceText.count, 0)
        XCTAssertLessThanOrEqual(viewModel.sourceText.count, AppViewModel.editorFillLimit)
    }

    private func makeAppViewModel() -> AppViewModel {
        AppViewModel(modelContext: .init(PersistenceController(inMemory: true).container))
    }
}
