import XCTest
import SwiftData
@testable import Helpme

/// Verifica di storia reale, consegnata da Marco il 29 agosto 2026: un
/// elenco di domande senza numerazione. La prima versione del riconoscitore
/// pretendeva "1." o "1)" e su questa non riconosceva niente, mandandola al
/// modello — che ne ha persa una per strada fondendo l'ottava e la nona.
final class UnnumberedExamTests: XCTestCase {

    private let storia = """
    Verifica di Storia

    Che cosa s'intende per "potere universale"?
    Perché l'Impero e la Chiesa, nel Medioevo, esercitavano un potere universale?
    Concretamente, come poteva l'imperatore controllare un territorio tanto vasto?
    Com'era organizzato il territorio in epoca feudale?
    Qual è la differenza fra l'Impero e il Regno?
    Chi era il re? Come emerge la sua figura?
    Quali mutamenti di ordine economico provocano la crisi di come era organizzato il territorio nel medio evo?
    Qual è il senso dell'alleanza fra il re e la borghesia?
    Perché entrambi avevano interesse a indebolire la classe aristocratica?
    La rinnovata circolazione della moneta che cosa permetteva al re?
    Qual'era la principale attività economica della borghesia?
    Chi erano i funzionari?
    Perché erano decisivi per il mantenimento del potere del re?
    Perché era più facile governare uno Stato e non un impero?
    """

    /// Il numero è il punto: quattordici domande devono restare quattordici.
    func testAllFourteenQuestionsAreFound() {
        let esame = ExamParser.parse(storia)

        XCTAssertEqual(esame.questions.count, 14,
                       "Il modello ne aveva prodotte 13, fondendone due: \(esame.questions.map(\.text))")
    }

    /// La domanda che il modello aveva inghiottito dentro la precedente.
    func testTheQuestionTheModelSwallowedIsStillItsOwn() {
        let esame = ExamParser.parse(storia)

        XCTAssertTrue(esame.questions.contains { $0.text.contains("indebolire la classe aristocratica") },
                      "\(esame.questions.map(\.text))")
        XCTAssertFalse(esame.questions.contains { $0.text.contains("alleanza") && $0.text.contains("indebolire") },
                       "Sono due quesiti distinti, non uno con un sotto-punto.")
    }

    /// "Chi era il re? Come emerge la sua figura?" è un quesito solo, con due
    /// domande dentro: spezzarlo cambierebbe la prova.
    func testTwoQuestionMarksOnOneLineStayOneQuestion() {
        let esame = ExamParser.parse(storia)
        let quesito = esame.questions.first { $0.text.contains("Chi era il re") }

        XCTAssertNotNil(quesito)
        XCTAssertTrue(quesito!.text.contains("Come emerge la sua figura"), quesito!.text)
    }

    func testTheQuestionsAreNumberedInOrder() {
        let esame = ExamParser.parse(storia)

        XCTAssertEqual(esame.questions.first?.number, "1")
        XCTAssertEqual(esame.questions.last?.number, "14")
        XCTAssertTrue(esame.questions.first!.text.contains("potere universale"))
        XCTAssertTrue(esame.questions.last!.text.contains("governare uno Stato"))
    }

    func testTheTitleIsNotMistakenForAQuestion() {
        let esame = ExamParser.parse(storia)

        XCTAssertEqual(esame.title, "Verifica di Storia")
        XCTAssertFalse(esame.questions.contains { $0.text.contains("Verifica di Storia") })
    }

    /// Le verifiche numerate continuano a essere riconosciute come prima:
    /// la ricaduta non deve prendere il posto della lettura principale.
    func testNumberedExamsStillTakeThePrimaryPath() {
        let esame = ExamParser.parse("""
        1. Prima domanda con il suo punteggio. (punti 5)
        2. Seconda domanda?
        """)

        XCTAssertEqual(esame.questions.count, 2)
        XCTAssertEqual(esame.questions[0].points, 5, "Il percorso numerato legge i punteggi, la ricaduta no.")
    }

    /// Un elenco puntato di domande è la stessa cosa.
    func testABulletedListOfQuestionsWorksToo() {
        let esame = ExamParser.parse("""
        - Che cos'è il feudalesimo?
        - Chi erano i vassalli?
        """)
        XCTAssertEqual(esame.questions.count, 2)
        XCTAssertFalse(esame.questions[0].text.hasPrefix("-"), esame.questions[0].text)
    }

    /// Ma la prosa non deve diventare una verifica solo perché contiene una
    /// domanda retorica.
    func testProseWithARhetoricalQuestionIsNotAnExam() {
        let esame = ExamParser.parse("""
        Il nome segreto di Roma era noto a pochi sacerdoti. Perché tanto riserbo?
        Nel mondo antico il nome esprimeva l'essenza dell'entità che definiva, e
        conoscerlo dava potere su di essa.
        """)

        XCTAssertLessThanOrEqual(esame.questions.count, 1)
    }

    /// Il giro completo: la verifica di storia entra, esce il foglio.
    @MainActor
    func testTheHistoryExamIsRebuiltWithNoEngine() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.selectedFormat = .equipollenteExam
        vm.sourceText = storia

        await vm.generateMaterial()

        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.generatedContent.contains("potere universale"))
        XCTAssertTrue(vm.generatedContent.contains("**14.**"),
                      "Devono esserci tutti e quattordici i quesiti.")
    }
}

/// La griglia deve far risparmiare tempo, non darne da perdere.
final class GridIndicatorTests: XCTestCase {

    private func indicator(_ text: String) -> String {
        EquipollenteComposer.indicator(for: ExamQuestion(number: "1", text: text))
    }

    func testTheIndicatorFollowsHowTheQuestionIsAsked() {
        XCTAssertTrue(indicator("Perché l'Impero esercitava un potere universale?").contains("cause"))
        XCTAssertTrue(indicator("Come poteva l'imperatore controllare il territorio?").contains("procedimento"))
        XCTAssertTrue(indicator("Chi erano i funzionari?").contains("soggetti"))
        XCTAssertTrue(indicator("Quali mutamenti economici provocano la crisi?").contains("elenca"))
        XCTAssertTrue(indicator("Che cosa s'intende per potere universale?").contains("Lessico"))
        XCTAssertTrue(indicator("Qual è la differenza fra l'Impero e il Regno?").contains("distingue"))
    }

    /// L'apostrofo e' la forma piu' comune: "Com'era organizzato il
    /// territorio?" non deve ricadere sul generico.
    func testTheApostropheFormIsRecognised() {
        XCTAssertTrue(indicator("Com'era organizzato il territorio in epoca feudale?").contains("procedimento"))
    }

    /// L'interrogativo non sta sempre in testa alla frase.
    func testTheQuestionWordInTheMiddleOfTheSentenceIsFound() {
        XCTAssertNotEqual(
            indicator("La rinnovata circolazione della moneta che cosa permetteva al re?"),
            "Conoscenza dei contenuti")
    }

    func testImperativeAssignmentsAreRecognisedToo() {
        XCTAssertTrue(indicator("Descrivi il ciclo a quattro tempi.").contains("espone"))
        XCTAssertTrue(indicator("Calcola la potenza erogata.").contains("Applicazione"))
    }

    /// Quattordici righe identiche non fanno risparmiare niente a nessuno.
    func testARealExamGetsSeveralDifferentIndicators() {
        let domande = [
            "Che cosa s'intende per potere universale?",
            "Perché l'Impero esercitava un potere universale?",
            "Come poteva l'imperatore controllare il territorio?",
            "Chi erano i funzionari?"
        ]
        let indicatori = Set(domande.map { indicator($0) })

        XCTAssertGreaterThanOrEqual(indicatori.count, 4, "\(indicatori)")
    }
}
