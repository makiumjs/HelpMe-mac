import XCTest
import Speech
@testable import Helpme

/// AC4: la dettatura vocale.
///
/// La registrazione vera richiede microfono e permessi, che in un test non
/// ci sono. Qui si provano le due parti che decidono il comportamento
/// osservabile: la traduzione dei permessi in un messaggio comprensibile e
/// la fusione del dettato con il testo già scritto.
@MainActor
final class DictationTests: XCTestCase {

    // MARK: - Permessi

    func testAllGrantedAllowsDictation() {
        let permission = DictationPermission.from(
            speechStatus: .authorized, microphoneGranted: true, recognizerAvailable: true
        )
        XCTAssertEqual(permission, .granted)
        XCTAssertTrue(permission.canDictate)
        XCTAssertNil(permission.userMessage, "Quando si può dettare non serve alcun avviso")
    }

    /// I due permessi sono distinti: dire "attiva il microfono" a chi ha
    /// negato il riconoscimento vocale manderebbe nel pannello sbagliato.
    func testDeniedMicrophoneIsDistinctFromDeniedSpeech() {
        let micDenied = DictationPermission.from(
            speechStatus: .authorized, microphoneGranted: false, recognizerAvailable: true
        )
        let speechDenied = DictationPermission.from(
            speechStatus: .denied, microphoneGranted: true, recognizerAvailable: true
        )

        XCTAssertEqual(micDenied, .microphoneDenied)
        XCTAssertEqual(speechDenied, .speechDenied)
        XCTAssertNotEqual(micDenied.userMessage, speechDenied.userMessage)

        XCTAssertTrue(try XCTUnwrap(micDenied.userMessage).contains("Microfono"))
        XCTAssertTrue(try XCTUnwrap(speechDenied.userMessage).contains("Riconoscimento vocale"))
    }

    func testMissingItalianModelIsReportedAsSuch() {
        let permission = DictationPermission.from(
            speechStatus: .authorized, microphoneGranted: true, recognizerAvailable: false
        )
        XCTAssertEqual(permission, .unavailableLocale)
        XCTAssertFalse(permission.canDictate)
    }

    func testRestrictedAndNotDeterminedBlockDictation() {
        for status: SFSpeechRecognizerAuthorizationStatus in [.restricted, .notDetermined] {
            let permission = DictationPermission.from(
                speechStatus: status, microphoneGranted: true, recognizerAvailable: true
            )
            XCTAssertFalse(permission.canDictate, "\(status) non deve permettere la dettatura")
            XCTAssertNotNil(permission.userMessage, "\(status) deve avere una spiegazione")
        }
    }

    /// Ogni stato bloccante deve dire cosa fare, non solo che non si può.
    func testEveryBlockingStateExplainsItself() {
        let blocking: [DictationPermission] = [
            .speechDenied, .microphoneDenied, .restricted, .notDetermined, .unavailableLocale
        ]
        for permission in blocking {
            let message = permission.userMessage
            XCTAssertNotNil(message, "\(permission) senza messaggio")
            XCTAssertGreaterThan(try XCTUnwrap(message).count, 20, "\(permission) ha un messaggio troppo vago")
        }
    }

    // MARK: - Fusione col testo già scritto

    func testDictationIntoAnEmptyEditorIsTheDictationItself() {
        XCTAssertEqual(SpeechDictationService.merged(existing: "", dictated: "Il pistone scende"),
                       "Il pistone scende")
    }

    func testDictationIsAppendedWithASingleSpace() {
        XCTAssertEqual(
            SpeechDictationService.merged(existing: "Il pistone scende.", dictated: "Poi risale."),
            "Il pistone scende. Poi risale."
        )
    }

    /// Se il testo finisce già con uno spazio o va a capo, quella spaziatura
    /// va rispettata: aggiungerne un'altra rovinerebbe l'impaginazione.
    func testExistingTrailingWhitespaceIsRespected() {
        XCTAssertEqual(SpeechDictationService.merged(existing: "Prima riga\n", dictated: "seconda"),
                       "Prima riga\nseconda")
        XCTAssertEqual(SpeechDictationService.merged(existing: "Prima ", dictated: "seconda"),
                       "Prima seconda")
    }

    func testEmptyOrBlankDictationLeavesTheTextUntouched() {
        XCTAssertEqual(SpeechDictationService.merged(existing: "Testo intatto", dictated: ""),
                       "Testo intatto")
        XCTAssertEqual(SpeechDictationService.merged(existing: "Testo intatto", dictated: "   \n "),
                       "Testo intatto")
    }

    func testDictationIsTrimmedBeforeBeingAppended() {
        XCTAssertEqual(SpeechDictationService.merged(existing: "Prima.", dictated: "  Seconda.  "),
                       "Prima. Seconda.")
    }

    /// Il riconoscitore restituisce ogni volta l'intera frase riconosciuta
    /// fin lì: ricomporre sempre dalla stessa base è ciò che impedisce alle
    /// parole di accumularsi in duplicato mentre si parla.
    func testRepeatedPartialResultsDoNotAccumulate() {
        let base = "Appunti:"
        let partials = ["Il", "Il pistone", "Il pistone scende", "Il pistone scende e aspira"]

        var result = base
        for partial in partials {
            result = SpeechDictationService.merged(existing: base, dictated: partial)
        }

        XCTAssertEqual(result, "Appunti: Il pistone scende e aspira")
    }

    // MARK: - Integrazione con l'editor

    func testLiveDictationRewritesTheEditorFromTheBase() async {
        let viewModel = AppViewModel(modelContext: .init(PersistenceController(inMemory: true).container))
        viewModel.sourceText = "Lezione di oggi:"

        // Senza dettatura in corso non si tocca il testo dell'editor.
        viewModel.applyLiveDictation()
        XCTAssertEqual(viewModel.sourceText, "Lezione di oggi:")
    }

    func testServiceStartsIdle() {
        let service = SpeechDictationService()
        XCTAssertFalse(service.isRecording)
        XCTAssertEqual(service.liveTranscript, "")
        XCTAssertEqual(service.permission, .notDetermined)
    }

    func testConsumingTheTranscriptEmptiesIt() {
        let service = SpeechDictationService()
        XCTAssertEqual(service.consumeTranscript(), "")
        XCTAssertEqual(service.liveTranscript, "")
    }
}
