import XCTest
import SwiftData
@testable import Helpme

/// Il materiale generato e il testo di partenza vivevano solo in memoria: il
/// docente generava, chiudeva l'app, e il lavoro spariva senza che niente lo
/// avvertisse. Trovato perché Marco ha segnalato il pulsante «Copia»
/// disattivato — lo era a ragione, il materiale non c'era più.
final class WorkPersistenceTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: StudentProfile.self, GloLogEntry.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Il caso che ha fatto trovare il difetto: si chiude e si riapre.
    @MainActor
    func testTheWorkSurvivesClosingTheApp() throws {
        let container = try makeContainer()

        let prima = AppViewModel(modelContext: ModelContext(container))
        prima.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        prima.sourceText = "Verifica di Storia\n\nChi era il re?"
        prima.generatedContent = "## Verifica equipollente\n\n**1.** Chi era il re?"
        prima.rememberWork()

        // Una sessione nuova, come dopo un riavvio.
        let dopo = AppViewModel(modelContext: ModelContext(container))

        XCTAssertEqual(dopo.generatedContent, "## Verifica equipollente\n\n**1.** Chi era il re?")
        XCTAssertEqual(dopo.sourceText, "Verifica di Storia\n\nChi era il re?")
    }

    /// Cambiando alunno il lavoro non si perde: si mette via sulla sua
    /// scheda e torna quando lo si riseleziona.
    @MainActor
    func testSwitchingStudentKeepsEachOnesWork() throws {
        let vm = AppViewModel(modelContext: ModelContext(try makeContainer()))
        let andrea = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        let giulia = StudentProfile(name: "Giulia Bianchi", classInfo: "2ªB")
        vm.addStudent(andrea)
        vm.generatedContent = "Materiale di Andrea"

        vm.addStudent(giulia)
        XCTAssertEqual(vm.generatedContent, "", "L'alunna nuova parte da una scheda pulita.")
        vm.generatedContent = "Materiale di Giulia"

        vm.selectedStudent = andrea
        XCTAssertEqual(vm.generatedContent, "Materiale di Andrea", "Il lavoro torna con l'alunno.")

        vm.selectedStudent = giulia
        XCTAssertEqual(vm.generatedContent, "Materiale di Giulia")
    }

    /// Generare mette via da sé: non si deve dipendere dal fatto che il
    /// docente chiuda l'app in modo ordinato.
    @MainActor
    func testGeneratingRemembersWithoutBeingAsked() async throws {
        let container = try makeContainer()
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff
        let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        vm.addStudent(alunno)
        vm.selectedFormat = .pdpSummary

        await vm.generateMaterial()

        XCTAssertFalse(vm.generatedContent.isEmpty)
        XCTAssertEqual(alunno.lastGeneratedContent, vm.generatedContent,
                       "Il materiale dev'essere già sulla scheda, senza aspettare la chiusura.")
    }

    /// Il quiz scritto a mano vale come il materiale generato.
    @MainActor
    func testAHandWrittenQuizIsRememberedToo() throws {
        let vm = AppViewModel(modelContext: ModelContext(try makeContainer()))
        let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        vm.addStudent(alunno)

        vm.applyQuiz([QuizQuestion(prompt: "Chi era il re?", options: [
            QuizOption(text: "Il sovrano", isCorrect: true, explanation: nil),
            QuizOption(text: "Un funzionario", isCorrect: false, explanation: nil)
        ])])

        XCTAssertFalse(alunno.lastGeneratedContent.isEmpty)
    }

    /// Il difetto peggiore trovato mentre si scriveva questa funzione: con
    /// @Observable l'osservatore di `selectedStudent` scatta anche dentro
    /// l'inizializzatore, con oldValue nil. Salvando in quel caso sull'alunno
    /// appena selezionato, gli si sovrascriveva il materiale con lo stato
    /// vuoto in memoria — cioe' si cancellava il lavoro a ogni avvio.
    @MainActor
    func testOpeningTheAppDoesNotWipeTheSavedWork() throws {
        let container = try makeContainer()
        let prima = AppViewModel(modelContext: ModelContext(container))
        let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        prima.addStudent(alunno)
        prima.generatedContent = "Materiale che non deve sparire"
        prima.rememberWork()

        // Tre avvii di fila: se ne cancella uno, li cancella tutti.
        for tentativo in 1...3 {
            let sessione = AppViewModel(modelContext: ModelContext(container))
            XCTAssertEqual(sessione.generatedContent, "Materiale che non deve sparire",
                           "Perso all'avvio numero \(tentativo)")
        }
    }

    /// Mettere via senza cambiamenti non deve scrivere sul disco a vuoto.
    @MainActor
    func testRememberingWithNothingChangedIsANoOp() throws {
        let vm = AppViewModel(modelContext: ModelContext(try makeContainer()))
        let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        vm.addStudent(alunno)
        vm.generatedContent = "Materiale"
        vm.rememberWork()

        vm.rememberWork()   // di nuovo, senza aver toccato niente
        XCTAssertEqual(alunno.lastGeneratedContent, "Materiale")
        XCTAssertNil(vm.errorMessage)
    }
}
