import XCTest
@testable import Helpme

/// L'app deve funzionare su Mac molto diversi senza chiedere niente a nessuno.
@MainActor
final class EngineSelectorTests: XCTestCase {

    func testUsesSystemModelWhenNoApiKey() {
        let selector = EngineSelector(hasApiKey: false, systemStatus: .available)
        XCTAssertEqual(selector.usableEngines, [.systemModel])
        XCTAssertEqual(selector.recommended(for: .clearExplanation), .systemModel)
        // Anche per i formati impegnativi: meglio il modello locale che niente.
        XCTAssertEqual(selector.recommended(for: .equipollenteExam), .systemModel)
        XCTAssertNil(selector.blockingMessage)
    }

    func testUsesGeminiWhenSystemModelUnavailable() {
        let selector = EngineSelector(hasApiKey: true, systemStatus: .deviceNotEligible)
        XCTAssertEqual(selector.usableEngines, [.gemini])
        XCTAssertEqual(selector.recommended(for: .glossary), .gemini)
    }

    func testPrefersCloudForDemandingFormats() {
        let selector = EngineSelector(hasApiKey: true, systemStatus: .available)
        // Documenti lunghi e a vincoli multipli: meglio il cloud.
        XCTAssertEqual(selector.recommended(for: .equipollenteExam), .gemini)
        XCTAssertEqual(selector.recommended(for: .interactiveQuiz), .gemini)
        // Riscritture ed estrazioni: il modello locale basta e i dati restano qui.
        XCTAssertEqual(selector.recommended(for: .clearExplanation), .systemModel)
        XCTAssertEqual(selector.recommended(for: .glossary), .systemModel)
        XCTAssertEqual(selector.recommended(for: .conceptMap), .systemModel)
    }

    func testBlockingMessageExplainsBothWaysOut() {
        let selector = EngineSelector(hasApiKey: false, systemStatus: .appleIntelligenceOff)
        XCTAssertTrue(selector.usableEngines.isEmpty)
        let message = selector.blockingMessage ?? ""
        XCTAssertTrue(message.contains("Apple Intelligence"), "deve dire come attivare il modello locale")
        XCTAssertTrue(message.contains("Gemini"), "e deve indicare anche l'alternativa")
    }

    func testOldSystemFallsBackToCloud() {
        let selector = EngineSelector(hasApiKey: true, systemStatus: .systemTooOld)
        XCTAssertEqual(selector.recommended(for: .clearExplanation), .gemini)
        XCTAssertFalse(selector.isSystemModelUsable)
    }

    func testRationaleIsWrittenForTeachers() {
        let selector = EngineSelector(hasApiKey: true, systemStatus: .available)
        let local = selector.rationale(for: .glossary, engine: .systemModel)
        XCTAssertTrue(local.contains("non escono"), "deve dire perché conviene il locale: \(local)")

        let cloud = selector.rationale(for: .equipollenteExam, engine: .gemini)
        XCTAssertFalse(cloud.isEmpty)
    }

    func testEveryStatusExceptAvailableExplainsItself() {
        for status in [SystemModelAvailability.Status.appleIntelligenceOff, .deviceNotEligible,
                       .downloading, .systemTooOld, .unknown] {
            XCTAssertNotNil(status.explanation, "\(status) deve spiegarsi all'utente")
        }
        XCTAssertNil(SystemModelAvailability.Status.available.explanation)
    }

    // MARK: - Il ripiego rischioso va detto

    /// Misurato il 28/8/2026: sulla verifica equipollente il modello
    /// integrato risponde alle domande invece di lasciarle aperte e sbaglia
    /// i calcoli di un ordine di grandezza. Se non c'e alternativa lo si usa
    /// comunque — un attrezzo storto e meglio di nessun attrezzo — ma il
    /// docente deve saperlo prima di consegnare il foglio.
    func testFallbackToLocalModelOnDemandingFormatIsWarnedAbout() throws {
        let selector = EngineSelector(hasApiKey: false, systemStatus: .available)
        let engine = try XCTUnwrap(selector.recommended(for: .equipollenteExam))
        XCTAssertEqual(engine, .systemModel, "senza chiave resta solo il modello locale")

        let message = selector.rationale(for: .equipollenteExam, engine: engine)
        XCTAssertTrue(message.lowercased().contains("attenzione"), "Messaggio: \(message)")
        XCTAssertTrue(message.lowercased().contains("rileggi"),
                      "Il docente deve sapere che va riletto: \(message)")
    }

    /// Sui formati che il modello locale regge il messaggio non deve
    /// allarmare: un avviso ovunque e un avviso che nessuno legge piu.
    func testEasyFormatsOnLocalModelAreNotAlarming() {
        let selector = EngineSelector(hasApiKey: false, systemStatus: .available)
        let message = selector.rationale(for: .clearExplanation, engine: .systemModel)
        XCTAssertFalse(message.lowercased().contains("attenzione"), "Messaggio: \(message)")
    }

    func testFormatsThatNeedCloudAreExactlyTheMeasuredOnes() {
        XCTAssertTrue(DidacticFormat.equipollenteExam.needsCloudQuality)
        XCTAssertTrue(DidacticFormat.interactiveQuiz.needsCloudQuality)
        for format in [DidacticFormat.clearExplanation, .glossary, .conceptMap, .deskCheatSheet, .pdpSummary] {
            XCTAssertFalse(format.needsCloudQuality, "\(format) non dovrebbe pretendere il cloud")
        }
    }
}
