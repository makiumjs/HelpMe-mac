import XCTest
@testable import Helpme

/// Verifica costruita apposta per rompere il riconoscitore, con le forme che
/// i docenti usano davvero e che la prima versione non aveva mai visto.
/// Alla prima esecuzione perdeva un quesito, sbagliava la durata di mezz'ora
/// e cancellava gli spazi da riempire di un esercizio di completamento.
final class HardExamTests: XCTestCase {

    private let verifica = """
    VERIFICA DI SCIENZE DELLA TERRA
    Classe 2ª B — Prof.ssa Bianchi — 14 ottobre

    Durata della prova: un'ora e mezza. È consentito l'uso della calcolatrice.

    Parte prima: conoscenze di base

    1. Che cos'è una placca litosferica? [5 p.]

    2) Elenca i tre tipi di margine fra due placche e, per ciascuno, indica
       un esempio geografico reale.
       punti 6

    3 - Nel 1906 il terremoto di San Francisco rese celebre la faglia di
        Sant'Andrea. Perché quella faglia è considerata trasforme?

    Parte seconda: completamento e vero/falso

    4. Completa: il magma che raggiunge la superficie prende il nome di
       ______________, mentre quello che solidifica in profondità forma le
       rocce ______________. (punti 4)

    5. Indica se le seguenti affermazioni sono vere o false:
       • La crosta oceanica è più densa di quella continentale.  V  F
       • I terremoti profondi avvengono lungo le dorsali oceaniche.  V  F

    Parte terza: applicazione

    6. Un'onda sismica P viaggia a 6 km/s, una S a 3,5 km/s.
       a) Calcola la distanza dell'epicentro dalla stazione. (punti 3)
       b) Spiega perché il metodo richiede almeno tre stazioni. (punti 2)

    7. Osserva la carta allegata e completa la tabella:

       | Zona | Tipo di margine | Fenomeno prevalente |
       |------|-----------------|---------------------|
       | Islanda |  |  |
       | Giappone |  |  |

    8. «La Terra è un pianeta vivo»: che cosa intendeva Wegener?

    Punteggio totale: 30. La sufficienza è fissata a 18.
    """

    /// Il difetto peggiore: "3 - Nel 1906..." non era riconosciuto come
    /// quesito, e la prova ne perdeva uno per strada. E' lo stesso peccato
    /// che il modello aveva commesso sulla verifica di storia.
    func testNoQuestionIsLost() {
        let esame = ExamParser.parse(verifica)

        XCTAssertEqual(esame.questions.count, 8, "Riconosciuti: \(esame.questions.map(\.number))")
        XCTAssertTrue(esame.questions.contains { $0.text.contains("faglia") },
                      "Il quesito numerato con il trattino è sparito.")
    }

    /// "5 - 3 = 2" non e' un quesito numero cinque.
    func testAnArithmeticExpressionIsNotAQuestion() {
        XCTAssertNil(ExamParser.questionStart(in: "5 - 3 = 2"))
        XCTAssertNil(ExamParser.questionStart(in: "12 - 7"))
        XCTAssertNotNil(ExamParser.questionStart(in: "3 - Nel 1906 il terremoto..."))
    }

    /// Mezz'ora di differenza si trascina dentro il calcolo del tempo
    /// maggiorato: 90 diventano 120, non 78.
    func testAnHourAndAHalfIsNinetyMinutes() {
        XCTAssertEqual(ExamParser.parse(verifica).durationMinutes, 90)
        XCTAssertEqual(ExamParser.duration(in: "Durata: due ore e mezza"), 150)
        XCTAssertEqual(ExamParser.duration(in: "Hai un'ora"), 60)
    }

    /// Togliendo i trattini bassi sparisce lo spazio in cui l'alunno scrive.
    func testTheBlanksOfAClozeExerciseSurvive() {
        let esame = ExamParser.parse(verifica)
        let completamento = esame.questions.first { $0.text.hasPrefix("Completa") }

        let testo = try! XCTUnwrap(completamento).text
        XCTAssertTrue(testo.contains("______"), "Lo spazio da riempire è sparito: \(testo)")
        XCTAssertTrue(testo.contains("prende il nome di ______"), testo)
    }

    /// Appiattire una tabella su una riga sola distrugge l'esercizio, che sta
    /// proprio nella sua disposizione.
    func testATableToCompleteKeepsItsRows() {
        let esame = ExamParser.parse(verifica)
        let tabella = try! XCTUnwrap(esame.questions.first { $0.text.contains("| Zona |") })

        XCTAssertTrue(tabella.text.contains("\n| Islanda"), tabella.text)
        XCTAssertTrue(tabella.text.contains("\n| Giappone"), tabella.text)
    }

    func testTrueFalseItemsStayOnTheirOwnLines() {
        let esame = ExamParser.parse(verifica)
        let vf = try! XCTUnwrap(esame.questions.first { $0.text.contains("vere o false") })

        XCTAssertTrue(vf.text.contains("\n• La crosta oceanica"), vf.text)
        XCTAssertTrue(vf.text.contains("\n• I terremoti profondi"), vf.text)
    }

    // MARK: - Punteggi scritti in tutti i modi

    func testPointsInSquareBracketsAreRead() {
        let esame = ExamParser.parse(verifica)
        XCTAssertEqual(esame.questions.first?.points, 5, "[5 p.] non è stato letto")
    }

    func testPointsOnTheirOwnLineAreRead() {
        let esame = ExamParser.parse(verifica)
        let elenca = try! XCTUnwrap(esame.questions.first { $0.text.hasPrefix("Elenca") })
        XCTAssertEqual(elenca.points, 6, "«punti 6» su una riga a sé non è stato letto")
    }

    /// Se la prova dichiara il totale, quello vince: e' il numero giusto, e
    /// se la somma non torna vuol dire che il riconoscimento e' incompleto.
    func testTheDeclaredTotalWinsOverTheSum() {
        XCTAssertEqual(ExamParser.parse(verifica).totalPoints, 30)
    }

    /// Una consegna che comincia con una citazione e' comunque un quesito.
    func testAQuestionOpeningWithAQuotationIsRecognised() {
        let esame = ExamParser.parse(verifica)
        XCTAssertTrue(esame.questions.contains { $0.text.contains("Wegener") },
                      "\(esame.questions.map { $0.text.prefix(30) })")
    }

    func testTheSectionsAreAllFound() {
        let titoli = ExamParser.parse(verifica).sections.compactMap(\.title)
        XCTAssertTrue(titoli.contains { $0.contains("Parte prima") }, "\(titoli)")
        XCTAssertTrue(titoli.contains { $0.contains("Parte terza") }, "\(titoli)")
    }
}
