import XCTest
@testable import Helpme

/// Il testo di prova è la verifica di meccanica agraria vera usata per le
/// misurazioni: quesiti aperti, un problema con sotto-punti, terminologia.
final class ExamParserTests: XCTestCase {

    private let verifica = """
    VERIFICA DI MECCANICA AGRARIA
    Classe 3ª A — Indirizzo Agrario

    PARTE PRIMA — Domande aperte (punti 12)

    1. Descrivi il ciclo di funzionamento di un motore a quattro tempi,
       specificando per ciascuna fase la posizione del pistone e lo stato
       delle valvole. (punti 5)

    2. Spiega la differenza tra un motore ad accensione comandata e uno ad
       accensione spontanea. (punti 4)

    3. Illustra la funzione del filtro dell'aria. (punti 3)

    PARTE SECONDA — Problema applicativo (punti 6)

    4. Una trattrice da 90 kW lavora per 6 ore all'80% della potenza nominale.
       a) Calcola la potenza effettivamente erogata. (punti 2)
       b) Calcola il consumo totale di gasolio in kg. (punti 2)
       c) Converti il consumo in litri. (punti 2)

    Tempo a disposizione: 60 minuti.
    """

    func testEveryQuestionIsFound() {
        let esame = ExamParser.parse(verifica)

        XCTAssertEqual(esame.questions.count, 4)
        XCTAssertEqual(esame.questions.map(\.number), ["1", "2", "3", "4"])
    }

    func testTheSectionsAreKept() {
        let esame = ExamParser.parse(verifica)

        let titoli = esame.sections.compactMap(\.title)
        XCTAssertTrue(titoli.contains { $0.contains("PARTE PRIMA") }, "\(titoli)")
        XCTAssertTrue(titoli.contains { $0.contains("PARTE SECONDA") }, "\(titoli)")
    }

    /// Una domanda occupa tre righe: devono restare una domanda sola.
    func testAQuestionSpanningSeveralLinesStaysOneQuestion() {
        let esame = ExamParser.parse(verifica)
        let prima = esame.questions[0]

        XCTAssertTrue(prima.text.contains("quattro tempi"))
        XCTAssertTrue(prima.text.contains("stato delle valvole"), prima.text)
    }

    func testPointsAreReadAndRemovedFromTheQuestionText() {
        let esame = ExamParser.parse(verifica)

        XCTAssertEqual(esame.questions[0].points, 5)
        XCTAssertEqual(esame.questions[1].points, 4)
        XCTAssertFalse(esame.questions[0].text.contains("punti"),
                       "Il punteggio va nella griglia, non nel testo del quesito: \(esame.questions[0].text)")
    }

    func testSubItemsBelongToTheirQuestion() {
        let esame = ExamParser.parse(verifica)
        let problema = esame.questions[3]

        XCTAssertEqual(problema.subItems.count, 3)
        XCTAssertTrue(problema.subItems[0].contains("potenza effettivamente erogata"))
        XCTAssertEqual(esame.questions.count, 4, "a) b) c) non sono quesiti a sé.")
    }

    func testTheDurationIsRead() {
        XCTAssertEqual(ExamParser.parse(verifica).durationMinutes, 60)
        XCTAssertEqual(ExamParser.duration(in: "Tempo: 90 min"), 90)
        XCTAssertEqual(ExamParser.duration(in: "Durata: due ore"), 120)
        XCTAssertEqual(ExamParser.duration(in: "Hai un'ora per svolgere la prova"), 60)
        XCTAssertNil(ExamParser.duration(in: "Nessuna indicazione di tempo"))
    }

    /// 5 + 4 + 3 della prima parte, piu' 2 + 2 + 2 dei sotto-punti del
    /// problema: e' quello che dicono le intestazioni della prova stessa,
    /// "(punti 12)" e "(punti 6)".
    func testTotalPointsAreAddedUpIncludingSubItems() {
        let esame = ExamParser.parse(verifica)

        XCTAssertEqual(esame.questions[3].points, 6, "Un problema in tre parti non vale zero.")
        XCTAssertEqual(esame.totalPoints, 18)
    }

    /// La durata chiude la prova: non e' parte dell'ultimo quesito.
    func testTheDurationLineDoesNotEndUpInsideTheLastQuestion() {
        let esame = ExamParser.parse(verifica)

        for quesito in esame.questions {
            XCTAssertFalse(quesito.text.lowercased().contains("tempo a disposizione"),
                           "Finirebbe stampata nella domanda: \(quesito.text)")
        }
    }

    // MARK: - Altre forme di scrittura

    func testQuestionsWrittenWithBracketsAreFoundToo() {
        let esame = ExamParser.parse("""
        1) Prima domanda
        2) Seconda domanda
        """)
        XCTAssertEqual(esame.questions.count, 2)
    }

    func testPointsWrittenTheOtherWayRound() {
        XCTAssertEqual(ExamParser.points(in: "Domanda (5 punti)"), 5)
        XCTAssertEqual(ExamParser.points(in: "Domanda punti: 8"), 8)
        XCTAssertEqual(ExamParser.points(in: "Domanda (punti 3)"), 3)
    }

    /// Un testo che non è una verifica non deve produrre una finta struttura.
    func testProseWithoutQuestionsYieldsNothing() {
        let esame = ExamParser.parse("""
        Il nome segreto di Roma era noto a pochi sacerdoti. Nel mondo antico si
        riteneva che il nome esprimesse l'essenza dell'entità che definiva.
        """)
        XCTAssertTrue(esame.isEmpty, "Meglio ammettere di non aver riconosciuto niente: \(esame)")
    }

    /// Una data a inizio riga non è un quesito.
    func testADateIsNotAQuestion() {
        XCTAssertNil(ExamParser.questionStart(in: "1492. Scoperta dell'America"))
        XCTAssertNil(ExamParser.questionStart(in: "2026) anno in corso"))
    }

    func testAnEmptyTextIsHandled() {
        XCTAssertTrue(ExamParser.parse("").isEmpty)
        XCTAssertTrue(ExamParser.parse("   \n\n  ").isEmpty)
    }
}
