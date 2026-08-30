import XCTest
@testable import Helpme

/// Il cantiere è il passo dopo la misurazione: l'analizzatore dice quali
/// frasi sono il problema, qui il docente le riscrive e il testo si rimonta
/// da solo — senza copia-incolla da sbagliare.
final class SimplificationDraftTests: XCTestCase {

    private let testo = """
    La litosfera, che costituisce lo strato rigido più esterno del pianeta e che
    viene suddivisa in placche assai variabili, è caratterizzata da fragilità.

    Le placche si muovono. I margini sono tre.
    """

    func testEverySentenceBecomesARow() {
        let righe = SimplificationDraft.rows(from: testo)
        XCTAssertEqual(righe.count, 3)
        XCTAssertTrue(righe[0].original.hasPrefix("La litosfera"))
    }

    func testTheDifficultOnesAreMarkedAndTheEasyOnesAreNot() {
        let righe = SimplificationDraft.rows(from: testo)
        XCTAssertTrue(righe[0].reading.needsWork, "\(righe[0].reading.reasons)")
        XCTAssertFalse(righe[1].reading.needsWork, "«Le placche si muovono» non ha niente che non va.")
    }

    /// Non toccando niente, il testo torna quello di prima — solo impaginato.
    func testWithoutRewritingAnythingTheTextIsUnchanged() {
        let righe = SimplificationDraft.rows(from: testo)
        let rimontato = SimplificationDraft.assemble(righe)

        XCTAssertTrue(rimontato.contains("La litosfera, che costituisce"))
        XCTAssertTrue(rimontato.contains("Le placche si muovono."))
        XCTAssertEqual(
            Set(ReadabilityAnalyzer.wordsOf(rimontato).map { $0.lowercased() }),
            Set(ReadabilityAnalyzer.wordsOf(testo).map { $0.lowercased() }))
    }

    func testARewrittenSentenceTakesThePlaceOfTheOriginal() {
        var righe = SimplificationDraft.rows(from: testo)
        righe[0].rewritten = "La litosfera è lo strato duro esterno della Terra."

        let rimontato = SimplificationDraft.assemble(righe)
        XCTAssertTrue(rimontato.contains("La litosfera è lo strato duro esterno della Terra."))
        XCTAssertFalse(rimontato.contains("che costituisce"), "L'originale sparisce: \(rimontato)")
        XCTAssertTrue(rimontato.contains("Le placche si muovono."), "Le altre restano com'erano.")
    }

    /// Una casella lasciata con soli spazi non è una riscrittura.
    func testWhitespaceIsNotARewrite() {
        var riga = SimplificationDraft.rows(from: testo)[1]
        riga.rewritten = "   \n "
        XCTAssertFalse(riga.isRewritten)
        XCTAssertEqual(riga.final, riga.original)
    }

    /// I paragrafi restano dov'erano, invece di appiattirsi in un blocco.
    func testParagraphsAreKept() {
        let righe = SimplificationDraft.rows(from: testo)
        XCTAssertTrue(righe[0].endsParagraph)
        XCTAssertFalse(righe[1].endsParagraph)
        XCTAssertTrue(righe[2].endsParagraph)
        XCTAssertTrue(SimplificationDraft.assemble(righe).contains("\n---\n"))
    }

    /// L'indice si muove mentre si lavora: è il riscontro che dice se la
    /// riscrittura sta servendo.
    func testTheIndexImprovesAsSentencesAreRewritten() {
        var righe = SimplificationDraft.rows(from: testo)
        let prima = SimplificationDraft.currentGulpease(righe)

        righe[0].rewritten = "La litosfera è lo strato duro della Terra. È divisa in placche."
        let dopo = SimplificationDraft.currentGulpease(righe)

        XCTAssertGreaterThan(dopo, prima, "prima=\(prima) dopo=\(dopo)")
    }

    /// Le parole già spiegate per quell'alunno compaiono proprio mentre si
    /// riscrive la frase che le contiene.
    func testTheStudentsOwnWordsAreOfferedWhereTheyServe() {
        let riga = SimplificationDraft.rows(from: testo)[0]
        let aiuti = SimplificationDraft.hints(for: riga, glossary: ["litosfera": "lo strato duro esterno"])

        XCTAssertEqual(aiuti.count, 1)
        XCTAssertEqual(aiuti.first?.1, "lo strato duro esterno")
    }

    func testAnEmptyTextGivesNoRows() {
        XCTAssertTrue(SimplificationDraft.rows(from: "   \n\n ").isEmpty)
        XCTAssertEqual(SimplificationDraft.assemble([]), "")
    }
}
