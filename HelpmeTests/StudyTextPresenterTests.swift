import XCTest
@testable import Helpme

/// L'area di lettura non deve svelare le risposte del quiz.
///
/// Il formato che il prompt chiede al modello marca la risposta esatta con
/// `- [x]` e spiega ogni opzione: mostrarlo tale e quale allo studente vuol
/// dire fargli leggere la soluzione prima che apra l'autoverifica.
final class StudyTextPresenterTests: XCTestCase {

    private let quiz = """
    ### Domanda 1
    Durante quale fase il pistone comprime la miscela?
    - [ ] Aspirazione :: no, in aspirazione il pistone scende
    - [x] Compressione :: esatto, il pistone risale con le valvole chiuse
    - [ ] Scoppio :: la candela accende la miscela
    """

    func testCorrectAnswerMarkerIsNotShown() {
        let readable = StudyTextPresenter.readable(quiz)
        XCTAssertFalse(readable.contains("[x]"), "La risposta esatta resta marcata: \(readable)")
        XCTAssertFalse(readable.contains("[ ]"))
    }

    /// Anche la spiegazione va tolta: "esatto, …" rivelerebbe la soluzione
    /// altrettanto bene del marcatore.
    func testPerOptionExplanationsAreNotShown() {
        let readable = StudyTextPresenter.readable(quiz)
        XCTAssertFalse(readable.contains("esatto"), "La spiegazione svela la risposta: \(readable)")
        XCTAssertFalse(readable.contains("no, in aspirazione"))
    }

    func testOptionsRemainReadableAsAList() {
        let readable = StudyTextPresenter.readable(quiz)
        XCTAssertTrue(readable.contains("• Aspirazione"))
        XCTAssertTrue(readable.contains("• Compressione"))
        XCTAssertTrue(readable.contains("• Scoppio"))
    }

    func testQuestionSurvivesWithoutItsHashes() {
        let readable = StudyTextPresenter.readable(quiz)
        XCTAssertTrue(readable.contains("Domanda 1"))
        XCTAssertFalse(readable.contains("###"))
        XCTAssertTrue(readable.contains("Durante quale fase il pistone comprime la miscela?"))
    }

    // MARK: - Il resto del materiale non va toccato

    func testPlainProseIsLeftAlone() {
        let prose = """
        Il motore a quattro tempi compie quattro fasi.
        Ogni fase ha un compito preciso.
        """
        XCTAssertEqual(StudyTextPresenter.readable(prose), prose)
    }

    func testConceptMapBulletsAreLeftAlone() {
        let map = """
        - Il motore a quattro tempi
          - Aspirazione :: il pistone scende
        """
        let readable = StudyTextPresenter.readable(map)
        XCTAssertTrue(readable.contains("- Il motore a quattro tempi"))
        // Il dettaglio resta — serve — ma il separatore macchina diventa
        // una lineetta leggibile.
        XCTAssertTrue(readable.contains("Aspirazione — il pistone scende"),
                      "Nella mappa il dettaglio serve e va lasciato: \(readable)")
        XCTAssertFalse(readable.contains("::"), "Il separatore macchina non si legge")
    }

    func testEmptyContentStaysEmpty() {
        XCTAssertEqual(StudyTextPresenter.readable(""), "")
    }

    func testRepeatedBlankLinesAreCompacted() {
        let readable = StudyTextPresenter.readable("Prima riga\n\n\n\n\nSeconda riga")
        XCTAssertEqual(readable, "Prima riga\n\nSeconda riga")
    }

    /// La vista del docente e quella dello studente devono divergere solo
    /// qui: l'originale resta intatto per chi deve controllarlo.
    // MARK: - Il documento consegnato allo studente

    /// Il difetto originale: l'esportazione in Word passava il testo grezzo,
    /// e lo studente si ritrovava stampate sul foglio le risposte esatte.
    func testHandoutRemovesTheAnswerKey() {
        let handout = StudyTextPresenter.handout(quiz)
        XCTAssertFalse(handout.contains("[x]"), "il marcatore della risposta esatta è nel documento")
        XCTAssertFalse(handout.contains("[ ]"))
        XCTAssertFalse(handout.contains("esatto"), "la spiegazione rivela la risposta")
        XCTAssertFalse(handout.contains("no, in aspirazione"))
    }

    /// La differenza fondamentale con `readable(_:)`: qui il markdown deve
    /// sopravvivere, perché a valle diventa titoli, elenchi e tabelle nel
    /// documento Word. Appiattirlo rovinerebbe tutti i formati, non solo il quiz.
    func testHandoutKeepsMarkdownStructureIntact() {
        let handout = StudyTextPresenter.handout(quiz)
        XCTAssertTrue(handout.contains("### Domanda 1"), "il titolo markdown è stato appiattito: \(handout)")
        XCTAssertTrue(handout.contains("- Aspirazione"), "l'opzione non è più un punto elenco: \(handout)")
        XCTAssertTrue(handout.contains("- Compressione"))
    }

    /// La griglia di valutazione è una tabella markdown: deve arrivare
    /// intatta a `MarkdownToOoxml`, che la converte in tabella Word vera.
    func testHandoutLeavesTablesUntouched() {
        let withTable = """
        ## Griglia di valutazione

        | Indicatore | Punteggio |
        |---|---|
        | Comprensione | 0-3 |
        """
        XCTAssertEqual(StudyTextPresenter.handout(withTable), withTable)
    }

    func testHandoutLeavesNonQuizMaterialAlone() {
        let explanation = "# Il motore\n\nIl pistone scende.\n\n- Prima fase\n- Seconda fase"
        XCTAssertEqual(StudyTextPresenter.handout(explanation), explanation)
    }

    func testHandoutHumanisesTheMachineSeparator() {
        let map = "- Aspirazione :: il pistone scende"
        XCTAssertEqual(StudyTextPresenter.handout(map), "- Aspirazione — il pistone scende")
    }

    func testTheTeacherOriginalIsNotMutated() {
        let original = quiz
        _ = StudyTextPresenter.readable(original)
        XCTAssertEqual(original, quiz)
    }
}
