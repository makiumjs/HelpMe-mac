import XCTest
@testable import Helpme

/// AC5, parte quiz: le domande generate diventano cliccabili.
///
/// Il formato chiesto nel prompt è la casella `- [x]`, ma i modelli
/// derivano: il parser deve reggere anche le varianti che si incontrano,
/// perché una domanda persa in silenzio è peggio di una malformata.
final class QuizParserTests: XCTestCase {

    // MARK: - Formato chiesto nel prompt

    func testCheckboxFormatIsParsed() throws {
        let questions = QuizParser.parse("""
        ### Domanda 1
        Che cosa fa il pistone nella fase di aspirazione?
        - [ ] Risale comprimendo :: no, quella è la fase successiva
        - [x] Scende aspirando la miscela :: esatto, crea la depressione
        - [ ] Resta fermo :: il pistone non è mai fermo durante il ciclo
        - [ ] Espelle i gas :: quello avviene nella fase di scarico
        """)

        XCTAssertEqual(questions.count, 1)
        let question = try XCTUnwrap(questions.first)
        XCTAssertEqual(question.prompt, "Che cosa fa il pistone nella fase di aspirazione?")
        XCTAssertEqual(question.options.count, 4)
        XCTAssertTrue(question.isUsable)
        XCTAssertEqual(question.correctOption?.text, "Scende aspirando la miscela")
        XCTAssertEqual(question.correctOption?.explanation, "esatto, crea la depressione")
    }

    /// Anche le opzioni sbagliate portano la loro spiegazione: capire
    /// l'errore vale più che sapere la soluzione.
    func testWrongOptionsKeepTheirOwnExplanation() throws {
        let questions = QuizParser.parse("""
        ### Domanda 1
        Domanda?
        - [ ] Prima :: perché la prima è sbagliata
        - [x] Seconda :: perché la seconda è giusta
        """)
        let wrong = try XCTUnwrap(questions.first?.options.first)
        XCTAssertFalse(wrong.isCorrect)
        XCTAssertEqual(wrong.explanation, "perché la prima è sbagliata")
    }

    func testMultipleQuestionsAreSeparated() {
        let questions = QuizParser.parse("""
        ### Domanda 1
        Prima domanda?
        - [x] Giusta
        - [ ] Sbagliata

        ### Domanda 2
        Seconda domanda?
        - [ ] Sbagliata
        - [x] Giusta
        """)

        XCTAssertEqual(questions.count, 2)
        XCTAssertEqual(questions[0].prompt, "Prima domanda?")
        XCTAssertEqual(questions[1].prompt, "Seconda domanda?")
        XCTAssertTrue(questions.allSatisfy(\.isUsable))
    }

    // MARK: - Varianti che i modelli producono davvero

    func testLetteredOptionsWithACheckMarkAreParsed() throws {
        let questions = QuizParser.parse("""
        1. Qual è la funzione della clorofilla?
        A) Assorbire l'acqua
        B) Catturare la luce solare ✅
        C) Trasportare la linfa
        D) Irrigidire il fusto
        """)

        let question = try XCTUnwrap(questions.first)
        XCTAssertEqual(question.prompt, "Qual è la funzione della clorofilla?")
        XCTAssertEqual(question.correctOption?.text, "Catturare la luce solare")
        // Il segno di spunta non deve restare nel testo dell'opzione.
        XCTAssertFalse(try XCTUnwrap(question.correctOption?.text).contains("✅"))
    }

    func testCorrectAnswerStatedOnALaterLineIsApplied() throws {
        let questions = QuizParser.parse("""
        Domanda 1: Quante fasi ha il ciclo Otto?
        A) Due
        B) Quattro
        C) Sei
        Risposta corretta: B
        """)

        let question = try XCTUnwrap(questions.first)
        XCTAssertEqual(question.prompt, "Quante fasi ha il ciclo Otto?")
        XCTAssertEqual(question.correctOption?.text, "Quattro")
        XCTAssertTrue(question.isUsable)
    }

    func testParentheticalCorrectMarkerIsRecognised() throws {
        let questions = QuizParser.parse("""
        1. Domanda?
        A) Prima
        B) Seconda (corretta)
        """)
        XCTAssertEqual(questions.first?.correctOption?.text, "Seconda")
    }

    func testTrailingExplanationAttachesToTheCorrectOption() throws {
        let questions = QuizParser.parse("""
        1. Quante fasi ha il ciclo Otto?
        A) Due
        B) Quattro ✅
        Spiegazione: aspirazione, compressione, scoppio e scarico.
        """)
        XCTAssertEqual(questions.first?.correctOption?.explanation,
                       "aspirazione, compressione, scoppio e scarico.")
    }

    func testDotAndParenthesisLetterMarkersBothWork() {
        for marker in ["A)", "A.", "A:"] {
            let questions = QuizParser.parse("""
            1. Domanda?
            \(marker) Prima ✅
            B) Seconda
            """)
            XCTAssertEqual(questions.first?.correctOption?.text, "Prima",
                           "Il marcatore «\(marker)» non è stato riconosciuto")
        }
    }

    // MARK: - Scarti

    /// Senza esattamente una risposta giusta non c'è niente da verificare:
    /// meglio scartare la domanda che mostrarne una irrisolvibile.
    func testQuestionWithoutACorrectAnswerIsDiscarded() {
        let questions = QuizParser.parse("""
        ### Domanda 1
        Domanda senza soluzione?
        - [ ] Prima
        - [ ] Seconda
        """)
        XCTAssertTrue(questions.isEmpty)
    }

    func testQuestionWithTwoCorrectAnswersIsDiscarded() {
        let questions = QuizParser.parse("""
        ### Domanda 1
        Domanda ambigua?
        - [x] Prima
        - [x] Seconda
        """)
        XCTAssertTrue(questions.isEmpty)
    }

    func testQuestionWithASingleOptionIsDiscarded() {
        let questions = QuizParser.parse("""
        ### Domanda 1
        Domanda?
        - [x] Unica risposta
        """)
        XCTAssertTrue(questions.isEmpty)
    }

    func testProseWithoutQuestionsProducesNothing() {
        XCTAssertTrue(QuizParser.parse("Ecco un riassunto della lezione di oggi.").isEmpty)
        XCTAssertTrue(QuizParser.parse("").isEmpty)
    }

    /// Un preambolo dell'IA non deve diventare una domanda fantasma.
    func testIntroductoryLineDoesNotBecomeAQuestion() {
        let questions = QuizParser.parse("""
        Ecco il quiz di autoverifica sul ciclo a quattro tempi.

        ### Domanda 1
        Quante fasi ci sono?
        - [x] Quattro
        - [ ] Due
        """)
        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(questions.first?.prompt, "Quante fasi ci sono?")
    }

    // MARK: - Prompt e parser allineati

    func testTheFormatRequestedInThePromptParsesCorrectly() {
        let asRequested = """
        ### Domanda 1
        Testo della domanda?
        - [ ] Opzione sbagliata :: perché non è questa
        - [x] Opzione corretta :: perché è questa
        - [ ] Opzione sbagliata :: perché non è questa
        - [ ] Opzione sbagliata :: perché non è questa
        """
        let questions = QuizParser.parse(asRequested)

        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(questions.first?.options.count, 4)
        XCTAssertTrue(try! XCTUnwrap(questions.first).isUsable)
    }
}
