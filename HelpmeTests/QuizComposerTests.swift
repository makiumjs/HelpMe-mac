import XCTest
import SwiftData
@testable import Helpme

/// Finora il quiz si poteva ottenere solo da un modello: il markup che il
/// lettore si aspetta a mano non lo digita nessuno, e una parentesi quadra
/// sbagliata significa una domanda che non si può cliccare.
final class QuizComposerTests: XCTestCase {

    private let domanda = QuizQuestion(prompt: "Quale fase produce lavoro utile?", options: [
        QuizOption(text: "Aspirazione", isCorrect: false, explanation: "Entra la miscela, non si produce lavoro."),
        QuizOption(text: "Espansione", isCorrect: true, explanation: "È qui che la combustione spinge il pistone."),
        QuizOption(text: "Scarico", isCorrect: false, explanation: "Escono i gas combusti."),
        QuizOption(text: "Compressione", isCorrect: false, explanation: "Si spende lavoro, non se ne produce.")
    ])

    /// La proprietà che conta: scrivere e rileggere deve restituire le stesse
    /// domande. Se il compositore e il lettore divergono, il quiz smette di
    /// essere cliccabile e nessun test se ne accorge.
    func testWritingAndReadingBackGivesTheSameQuiz() {
        let riletto = QuizParser.parse(QuizComposer.compose([domanda]))

        XCTAssertEqual(riletto.count, 1)
        XCTAssertEqual(riletto[0].prompt, domanda.prompt)
        XCTAssertEqual(riletto[0].options.map(\.text), domanda.options.map(\.text))
        XCTAssertEqual(riletto[0].correctOption?.text, "Espansione")
        XCTAssertEqual(riletto[0].options[0].explanation, "Entra la miscela, non si produce lavoro.")
    }

    func testSeveralQuestionsAreNumberedInOrder() {
        let markup = QuizComposer.compose([domanda, domanda, domanda])

        XCTAssertTrue(markup.contains("### Domanda 1"))
        XCTAssertTrue(markup.contains("### Domanda 3"))
        XCTAssertEqual(QuizParser.parse(markup).count, 3)
    }

    /// Lo studente non deve vedere quale sia la risposta giusta: il marcatore
    /// c'è nel markup, ma il presentatore lo toglie.
    func testTheStudentDoesNotSeeTheAnswerMarker() {
        let perLoStudente = StudyTextPresenter.readable(QuizComposer.compose([domanda]))

        XCTAssertFalse(perLoStudente.contains("[x]"), perLoStudente)
        XCTAssertTrue(perLoStudente.contains("Espansione"), "L'opzione resta, è il segno che sparisce.")
    }

    func testAnOptionWithoutExplanationIsWrittenWithoutTheSeparator() {
        let senza = QuizQuestion(prompt: "Domanda?", options: [
            QuizOption(text: "Giusta", isCorrect: true, explanation: nil),
            QuizOption(text: "Sbagliata", isCorrect: false, explanation: nil)
        ])
        let markup = QuizComposer.compose([senza])

        XCTAssertFalse(markup.contains("::"), markup)
        XCTAssertEqual(QuizParser.parse(markup).first?.correctOption?.text, "Giusta")
    }

    // MARK: - La domanda in lavorazione

    /// Una domanda incompleta non finisce nel quiz: uno studente che clicca e
    /// non riceve riscontro smette di fidarsi della scheda.
    func testAnIncompleteQuestionDoesNotReachTheQuiz() {
        var bozza = QuizDraftQuestion()
        XCTAssertFalse(bozza.isComplete)

        bozza.prompt = "Quale fase produce lavoro utile?"
        XCTAssertFalse(bozza.isComplete, "Manca ancora la risposta segnata.")

        bozza.options[0].text = "Espansione"
        bozza.options[1].text = "Scarico"
        XCTAssertFalse(bozza.isComplete, "Le opzioni ci sono, la risposta giusta no.")

        bozza.correctIndex = 0
        XCTAssertTrue(bozza.isComplete)
        XCTAssertNotNil(bozza.asQuizQuestion())
    }

    /// Segnare come giusta una casella lasciata vuota non deve produrre un
    /// quiz in cui la risposta corretta è una riga bianca.
    func testMarkingAnEmptyOptionAsCorrectDoesNotProduceAQuiz() {
        var bozza = QuizDraftQuestion()
        bozza.prompt = "Domanda?"
        bozza.options[0].text = "Prima"
        bozza.options[1].text = "Seconda"
        bozza.correctIndex = 3        // rimasta vuota

        XCTAssertFalse(bozza.isComplete)
        XCTAssertNil(bozza.asQuizQuestion())
    }

    func testEmptyOptionsAreDroppedNotWrittenAsBlankRows() {
        var bozza = QuizDraftQuestion()
        bozza.prompt = "Domanda?"
        bozza.options[0].text = "Prima"
        bozza.options[1].text = "Seconda"
        bozza.correctIndex = 0

        XCTAssertEqual(bozza.asQuizQuestion()?.options.count, 2)
    }

    /// Riaprendo l'editor si ritrova quello che c'è, per correggerlo invece
    /// di riscriverlo.
    func testAnExistingQuizComesBackIntoTheEditor() {
        let bozza = QuizDraftQuestion(from: domanda)

        XCTAssertEqual(bozza.prompt, domanda.prompt)
        XCTAssertEqual(bozza.correctIndex, 1)
        XCTAssertEqual(bozza.options[1].explanation, "È qui che la combustione spinge il pistone.")
        XCTAssertEqual(bozza.asQuizQuestion()?.correctOption?.text, "Espansione")
    }

    // MARK: - Nell'app

    @MainActor
    func testTheWrittenQuizReachesTheMaterialWithNoEngine() throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff

        vm.applyQuiz([domanda])

        XCTAssertEqual(vm.selectedFormat, .interactiveQuiz)
        // È quello che fa la scheda dello studente con il materiale prodotto.
        let perLoStudente = QuizParser.parse(vm.generatedContent)
        XCTAssertEqual(perLoStudente.count, 1, "Deve arrivare cliccabile allo studente.")
        XCTAssertEqual(perLoStudente.first?.correctOption?.text, "Espansione")
        XCTAssertNil(vm.errorMessage)
    }
}
