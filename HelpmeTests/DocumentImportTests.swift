import XCTest
@testable import Helpme

/// AC1: il RAG smette di cercare dentro sé stesso.
///
/// Finché l'unica sorgente era il testo dell'editor, il retrieval ripescava
/// esattamente ciò che stava già per finire nel prompt.
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
        I trattori moderni adottano trasmissioni a variazione continua per il rendimento.
        """
        try Data(text.utf8).write(to: url)
        return url
    }

    // MARK: - Indicizzazione

    func testIndexingAFileAddsChunks() throws {
        let service = SemanticSearchService()
        XCTAssertEqual(service.indexedChunksCount, 0)

        let count = try service.indexDocument(url: try writeLesson(named: "meccanica.txt"))

        XCTAssertGreaterThan(count, 0)
        XCTAssertEqual(service.indexedChunksCount, count)
        XCTAssertEqual(service.indexedDocuments.map(\.title), ["meccanica"])
        XCTAssertEqual(service.indexedDocuments.first?.chunkCount, count)
    }

    func testIndexedContentIsRetrievable() throws {
        let service = SemanticSearchService()
        try service.indexDocument(url: try writeLesson(named: "meccanica.txt"))

        let hits = service.searchRelevantContext(query: "manutenzione dei trattori", topK: 2)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertEqual(hits.first?.documentTitle, "meccanica")
    }

    /// Reindicizzare lo stesso documento non deve raddoppiarne i frammenti,
    /// altrimenti i risultati si riempiono di duplicati dello stesso testo.
    func testReindexingReplacesInsteadOfDuplicating() throws {
        let service = SemanticSearchService()
        let url = try writeLesson(named: "meccanica.txt")

        let first = try service.indexDocument(url: url)
        let second = try service.indexDocument(url: url)

        XCTAssertEqual(first, second)
        XCTAssertEqual(service.indexedChunksCount, first)
        XCTAssertEqual(service.indexedDocuments.count, 1)
    }

    func testRemovingOneDocumentKeepsTheOthers() throws {
        let service = SemanticSearchService()
        try service.indexDocument(url: try writeLesson(named: "meccanica.txt"))
        try service.indexDocument(url: try writeLesson(named: "botanica.txt", body: """
        La fotosintesi trasforma la luce solare in energia chimica dentro le foglie.
        Le radici assorbono acqua e sali minerali dal terreno circostante.
        """))
        XCTAssertEqual(service.indexedDocuments.count, 2)

        service.removeDocument(title: "meccanica")

        XCTAssertEqual(service.indexedDocuments.map(\.title), ["botanica"])
        XCTAssertGreaterThan(service.indexedChunksCount, 0)
    }

    func testIndexingAnUnreadableFileThrowsInsteadOfSilentlySucceeding() throws {
        let url = scratch.appendingPathComponent("presentazione.key")
        try Data("x".utf8).write(to: url)

        let service = SemanticSearchService()
        XCTAssertThrowsError(try service.indexDocument(url: url))
        XCTAssertEqual(service.indexedChunksCount, 0, "Un file scartato non deve lasciare frammenti")
    }

    // MARK: - Attraverso il view model

    func testImportReportsSuccessAndKeepsIndexStateObservable() async throws {
        let viewModel = makeAppViewModel()
        let url = try writeLesson(named: "meccanica.txt")

        await viewModel.importDocuments(urls: [url])

        XCTAssertEqual(viewModel.indexedDocuments.map(\.title), ["meccanica"])
        XCTAssertGreaterThan(viewModel.indexedChunkCount, 0)
        XCTAssertFalse(viewModel.isImportingDocuments)
        XCTAssertNil(viewModel.errorMessage)
        let status = try XCTUnwrap(viewModel.statusMessage)
        XCTAssertTrue(status.contains("meccanica"), "Stato: \(status)")
    }

    /// Un file scartato viene detto. Ingoiarlo in silenzio farebbe credere
    /// al docente che quel materiale è consultabile dall'IA.
    func testImportSurfacesFailuresWithTheFileName() async throws {
        let viewModel = makeAppViewModel()
        let bad = scratch.appendingPathComponent("slide.key")
        try Data("x".utf8).write(to: bad)

        await viewModel.importDocuments(urls: [bad])

        XCTAssertTrue(viewModel.indexedDocuments.isEmpty)
        let error = try XCTUnwrap(viewModel.errorMessage)
        XCTAssertTrue(error.contains("slide.key"), "Errore: \(error)")
    }

    func testPartialImportReportsBothSidesSeparately() async throws {
        let viewModel = makeAppViewModel()
        let good = try writeLesson(named: "meccanica.txt")
        let bad = scratch.appendingPathComponent("slide.key")
        try Data("x".utf8).write(to: bad)

        await viewModel.importDocuments(urls: [good, bad])

        XCTAssertEqual(viewModel.indexedDocuments.map(\.title), ["meccanica"])
        XCTAssertNotNil(viewModel.statusMessage, "Il successo parziale va comunque riportato")
        XCTAssertNotNil(viewModel.errorMessage, "Il fallimento parziale va comunque riportato")
    }

    func testClearingTheIndexEmptiesIt() async throws {
        let viewModel = makeAppViewModel()
        await viewModel.importDocuments(urls: [try writeLesson(named: "meccanica.txt")])
        XCTAssertFalse(viewModel.indexedDocuments.isEmpty)

        viewModel.clearSemanticIndex()

        XCTAssertTrue(viewModel.indexedDocuments.isEmpty)
        XCTAssertEqual(viewModel.indexedChunkCount, 0)
    }

    func testIndexingEditorTextWithoutContentIsRefusedClearly() async {
        let viewModel = makeAppViewModel()
        viewModel.sourceText = "   \n  "

        await viewModel.indexEditorText()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.indexedDocuments.isEmpty)
    }

    func testIndexingEditorTextAddsChunks() async {
        let viewModel = makeAppViewModel()
        viewModel.sourceText = """
        Il motore a combustione interna a quattro tempi compie aspirazione,
        compressione, scoppio e scarico in due giri dell'albero motore.
        """

        await viewModel.indexEditorText()

        XCTAssertGreaterThan(viewModel.indexedChunkCount, 0)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.statusMessage)
    }

    private func makeAppViewModel() -> AppViewModel {
        AppViewModel(modelContext: .init(PersistenceController(inMemory: true).container))
    }
}
