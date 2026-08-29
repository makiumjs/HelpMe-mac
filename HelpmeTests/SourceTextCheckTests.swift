import XCTest
import SwiftData
@testable import Helpme

/// Il caso che ha fatto trovare il difetto: nel riquadro del testo
/// curricolare finisce una richiesta all'IA, e l'app ne fa un documento
/// ufficiale sull'argomento sbagliato.
final class SourceTextCheckTests: XCTestCase {

    func testTheRequestThatCausedThisIsCaught() {
        XCTAssertTrue(SourceTextCheck.looksLikeAnInstruction("genera verifica sulla base del documento"))
    }

    func testOtherWaysOfAskingAreCaughtToo() {
        for richiesta in [
            "Crea un quiz sul ciclo di Otto",
            "fammi una mappa concettuale",
            "Trasforma il documento importato",
            "riassumi il capitolo 4",
            "  PREPARA UNA VERIFICA  "
        ] {
            XCTAssertTrue(SourceTextCheck.looksLikeAnInstruction(richiesta), richiesta)
        }
    }

    /// Il caso da non rompere: una lezione vera passa, anche corta, anche se
    /// comincia per caso con un verbo all'imperativo.
    func testRealLessonsAreNotBlocked() {
        for lezione in [
            "Il ciclo Otto a quattro tempi.",
            "La fotosintesi clorofilliana trasforma l'energia luminosa in energia chimica.",
            "Verifica di meccanica agraria — Classe 3ª A"
        ] {
            XCTAssertFalse(SourceTextCheck.looksLikeAnInstruction(lezione), lezione)
        }
    }

    /// Un testo lungo è un testo, comunque cominci: una consegna d'esame può
    /// benissimo aprirsi con "Prendi un cilindro di raggio r...".
    func testALongTextIsATextWhateverItStartsWith() {
        let consegna = "Prendi un cilindro di raggio r e altezza h, riempito di gas perfetto "
            + "alla pressione iniziale p1. Il pistone viene spinto verso il basso fino a "
            + "dimezzare il volume disponibile. Calcola la pressione finale, supponendo la "
            + "trasformazione isoterma, e discuti come cambierebbe il risultato se la "
            + "trasformazione fosse adiabatica."
        XCTAssertGreaterThan(consegna.count, 200)
        XCTAssertFalse(SourceTextCheck.looksLikeAnInstruction(consegna))
    }

    func testEmptyTextIsNotAnInstruction() {
        XCTAssertFalse(SourceTextCheck.looksLikeAnInstruction(""))
        XCTAssertFalse(SourceTextCheck.looksLikeAnInstruction("   \n  "))
    }

    func testTheExplanationQuotesTheTeachersOwnWordsAndOffersBothWaysOut() {
        let messaggio = SourceTextCheck.instructionExplanation(for: "genera verifica sulla base del documento")

        XCTAssertTrue(messaggio.contains("genera verifica"), messaggio)
        XCTAssertTrue(messaggio.contains("Importa"), "Va indicata la via più corta: \(messaggio)")
    }

    /// E soprattutto: non si genera niente.
    @MainActor
    func testNothingIsGeneratedFromAnInstruction() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = AppViewModel(modelContext: ModelContext(container))
        viewModel.addStudent(StudentProfile(name: "Paolo Gialli", classInfo: "3ª B"))
        viewModel.sourceText = "genera verifica sulla base del documento"

        await viewModel.generateMaterial()

        XCTAssertTrue(viewModel.generatedContent.isEmpty,
                      "Da una richiesta non deve uscire un documento ufficiale.")
        XCTAssertNotNil(viewModel.errorMessage)
    }
}
