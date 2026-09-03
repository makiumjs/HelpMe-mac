import XCTest
@testable import Helpme

/// Due indicazioni di Marco, 29 agosto 2026: «in una verifica tutti i
/// quesiti hanno punteggio» e «conviene spezzare ancora».
final class GuidedStepsTests: XCTestCase {

    private func foglio(_ testo: String) -> String {
        EquipollenteComposer.compose(.init(
            studentName: "Andrea Pirlo", classInfo: "1ITA",
            programTitle: ProgramType.minimi.localizedTitle,
            compensatory: ["comp.formulari"], dispensatory: ["disp.tempi"],
            exam: ExamParser.parse(testo)))
    }

    // MARK: - Tutti i quesiti hanno un punteggio

    /// Il residuo dichiarato si divide fra i quesiti scoperti.
    func testTheDeclaredRemainderIsSpreadOverTheUnscoredQuestions() {
        let esame = ExamParser.parse("""
        1. Prima domanda? (punti 5)
        2. Seconda domanda?
        3. Terza domanda?

        Punteggio totale: 11.
        """)
        let (punti, proposti) = EquipollenteComposer.pointsByQuestion(esame)

        XCTAssertEqual(punti["1"], 5)
        XCTAssertEqual(punti["2"], 3)
        XCTAssertEqual(punti["3"], 3)
        XCTAssertEqual(proposti, ["2", "3"])
        XCTAssertEqual(punti.values.reduce(0, +), 11, "Il totale dichiarato dev'essere rispettato.")
    }

    /// L'avanzo va ai primi, non si perde: 10 su 4 fa 3, 3, 2, 2.
    func testTheLeftoverPointGoesToTheEarlierQuestions() {
        let esame = ExamParser.parse("""
        1. Una? 
        2. Due?
        3. Tre?
        4. Quattro?

        Punteggio totale: 10.
        """)
        let punti = EquipollenteComposer.pointsByQuestion(esame).points

        XCTAssertEqual(punti.values.reduce(0, +), 10)
        XCTAssertEqual(punti["1"], 3)
        XCTAssertEqual(punti["4"], 2)
    }

    /// Senza totale dichiarato, i quesiti scoperti prendono la media.
    func testWithoutADeclaredTotalTheAverageIsUsed() {
        let esame = ExamParser.parse("""
        1. Una? (punti 6)
        2. Due? (punti 4)
        3. Tre?
        """)
        XCTAssertEqual(EquipollenteComposer.pointsByQuestion(esame).points["3"], 5)
    }

    /// Senza niente, un punto per quesito: un segnaposto onesto, non zero.
    func testWithNoPointsAtAllEveryQuestionGetsOne() {
        let esame = ExamParser.parse("1. Una?\n2. Due?")
        let (punti, proposti) = EquipollenteComposer.pointsByQuestion(esame)

        XCTAssertEqual(punti["1"], 1)
        XCTAssertEqual(proposti.count, 2)
    }

    /// Nessuna casella vuota nella griglia, e si vede quali sono proposte.
    func testTheGridHasNoEmptyCellsAndSaysWhichAreProposed() {
        let testo = foglio("""
        1. Prima domanda? (punti 5)
        2. Seconda domanda?

        Punteggio totale: 9.
        """)
        XCTAssertTrue(testo.contains("| *4* |"), "Il punteggio proposto va in corsivo: \(testo)")
        XCTAssertTrue(testo.contains("quesiti 2"), testo)
        XCTAssertTrue(testo.contains("da confermare"), testo)
    }

    // MARK: - Spezzare ancora

    /// Un problema da calcolare si scompone sempre nelle stesse quattro
    /// mosse: è quello che un docente di sostegno scrive a mano ogni volta.
    func testACalculationIsBrokenIntoItsSteps() {
        let passi = try! XCTUnwrap(EquipollenteComposer.guidedSteps(for: "Calcola la distanza dell'epicentro."))

        XCTAssertTrue(passi.contains { $0.hasPrefix("Dati che hai") })
        XCTAssertTrue(passi.contains { $0.hasPrefix("Formula che userai") })
        XCTAssertTrue(passi.contains { $0.contains("unità di misura") })
    }

    func testTheStepsReachTheSheetUnderTheSubItem() {
        let testo = foglio("""
        1. Un'onda P viaggia a 6 km/s.
           a) Calcola la distanza dell'epicentro. (punti 3)
           b) Spiega perché servono tre stazioni. (punti 2)
        """)
        XCTAssertTrue(testo.contains("Formula che userai"), testo)
        // La spiegazione non è un calcolo: righe normali, non lo schema.
        let dopoB = String(testo[testo.range(of: "b) Spiega")!.upperBound...])
        XCTAssertFalse(dopoB.contains("Formula che userai"), dopoB)
    }

    /// "Elenca i tre tipi di margine" → tre caselle numerate, non un unico
    /// spazio in cui incastrarli tutti.
    func testAnEnumerationGetsOneBoxPerItem() {
        let passi = try! XCTUnwrap(EquipollenteComposer.guidedSteps(for: "Elenca i tre tipi di margine fra due placche."))

        XCTAssertEqual(passi.count, 3)
        XCTAssertTrue(passi[0].hasPrefix("1."))
        XCTAssertTrue(passi[2].hasPrefix("3."))
    }

    /// "Elenca i tre tipi di margine fra due placche" contiene due numeri:
    /// vale il primo, che e' quello che qualifica la cosa da elencare.
    func testWithTwoNumbersTheFirstOneWins() {
        XCTAssertEqual(EquipollenteComposer.requestedCount(in: "elenca i tre tipi di margine fra due placche"), 3)
        XCTAssertEqual(EquipollenteComposer.requestedCount(in: "indica due esempi per ciascuno dei tre casi"), 2)
    }

    func testTheEnumerationCountIsReadFromDigitsToo() {
        XCTAssertEqual(EquipollenteComposer.requestedCount(in: "elenca 4 cause della crisi"), 4)
        XCTAssertEqual(EquipollenteComposer.requestedCount(in: "indica due esempi"), 2)
    }

    /// Ma una domanda aperta non si scompone da sola: quella parte richiede
    /// di conoscere l'alunno e resta al docente.
    func testAnOpenQuestionIsNotScaffoldedAutomatically() {
        XCTAssertNil(EquipollenteComposer.guidedSteps(for: "Perché quella faglia è considerata trasforme?"))
        XCTAssertNil(EquipollenteComposer.guidedSteps(for: "Che cos'è una placca litosferica?"))
    }

    func testCalculationWithLeadingNumberAndContextIsBrokenIntoSteps() {
        let passi = try! XCTUnwrap(EquipollenteComposer.guidedSteps(for: "1. Dato un rettangolo di base 10 cm, calcola l'area."))

        XCTAssertTrue(passi.contains { $0.hasPrefix("Dati che hai") })
        XCTAssertTrue(passi.contains { $0.hasPrefix("Formula che userai") })
        XCTAssertTrue(passi.contains { $0.contains("unità di misura") })
    }

    func testComparisonQuestionIsScaffoldedIntoTable() {
        let passi = try! XCTUnwrap(EquipollenteComposer.guidedSteps(for: "Confronta il modello geocentrico e il modello eliocentrico."))

        XCTAssertTrue(passi.contains { $0.contains("Elementi a confronto") })
        XCTAssertTrue(passi.contains { $0.contains("|---|---|---|") })
        XCTAssertTrue(passi.contains { $0.contains("Sintesi finale") })
    }
}
