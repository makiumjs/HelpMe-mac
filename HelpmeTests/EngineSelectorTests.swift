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
}
