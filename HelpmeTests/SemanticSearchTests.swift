import XCTest
@testable import Helpme

final class SemanticSearchTests: XCTestCase {

    func testCosineSimilarityIdenticalVectors() {
        let vector: [Float] = [1.0, 0.0, 0.0, 1.0]
        XCTAssertEqual(VectorStore.cosineSimilarity(a: vector, b: vector), 1.0, accuracy: 0.0001)
    }

    func testCosineSimilarityOrthogonalVectors() {
        XCTAssertEqual(VectorStore.cosineSimilarity(a: [1.0, 0.0], b: [0.0, 1.0]), 0.0, accuracy: 0.0001)
    }

    func testChunkingAndSearch() {
        let searchService = SemanticSearchService()
        let lesson = """
        Il motore a combustione interna a quattro tempi si compone di aspirazione, compressione, scoppio ed espansione, e scarico.
        Nelle macchine agricole, la manutenzione periodica dei filtri dell'aria e dell'olio previene l'usura dei cilindri.
        I trattori moderni utilizzano trasmissioni a variazione continua CVT per massimizzare il rendimento del carburante.
        """

        let chunkCount = searchService.indexRawText(text: lesson, title: "Meccanica Agraria")
        XCTAssertGreaterThan(chunkCount, 0)
        XCTAssertEqual(searchService.indexedChunksCount, chunkCount)
        XCTAssertFalse(searchService.searchRelevantContext(query: "trattori e motori agricoli", topK: 2).isEmpty)
    }

    /// Il difetto precedente: `String.hashValue` è randomizzato a ogni avvio
    /// del processo, quindi un indice salvato oggi non si ritrovava domani.
    func testEmbeddingIsStableAcrossCalls() {
        let text = "manutenzione dei filtri dell'olio nel trattore"
        let first = DocumentIndexer.embedding(for: text)
        let second = DocumentIndexer.embedding(for: text)

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second)
    }

    func testStableHashIsDeterministic() {
        // Valori attesi del FNV-1a: non devono cambiare tra le esecuzioni,
        // altrimenti gli indici salvati diventano illeggibili.
        XCTAssertEqual(DocumentIndexer.stableHash(""), 0xcbf29ce484222325)
        XCTAssertEqual(DocumentIndexer.stableHash("a"), 0xaf63dc4c8601ec8c)
        XCTAssertEqual(DocumentIndexer.stableHash("trattore"), DocumentIndexer.stableHash("trattore"))
        XCTAssertNotEqual(DocumentIndexer.stableHash("trattore"), DocumentIndexer.stableHash("aratro"))
    }

    func testFallbackEmbeddingIsNormalized() {
        let vector = DocumentIndexer.deterministicFallback(words: ["motore", "trattore", "filtro"])
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        XCTAssertEqual(norm, 1.0, accuracy: 0.0001)
    }

    func testChunksCarryDocumentTitle() {
        let indexer = DocumentIndexer()
        let chunks = indexer.chunkText(
            text: String(repeating: "Il ciclo dell'azoto nel terreno agrario. ", count: 40),
            title: "Agronomia"
        )
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.documentTitle == "Agronomia" })
        XCTAssertTrue(chunks.allSatisfy { !$0.embedding.isEmpty })
    }

    func testUnsupportedFileTypeGivesReadableError() {
        let indexer = DocumentIndexer()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("prova.docx")
        try? Data([0x50, 0x4B, 0x03, 0x04]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try indexer.extractText(from: url)) { error in
            let message = (error as NSError).localizedDescription
            XCTAssertTrue(message.contains("docx") || message.contains("non supportato"),
                          "l'errore deve dire quale formato è stato rifiutato: \(message)")
        }
    }
}
