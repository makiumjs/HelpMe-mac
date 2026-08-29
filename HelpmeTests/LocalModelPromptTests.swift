import XCTest
import SwiftData
@testable import Helpme

/// Il modello integrato nel Mac, arrivato a una tabella markdown, comincia a
/// incolonnare le celle con spazi e non smette piu', finche' esaurisce la
/// finestra di contesto e la generazione fallisce.
///
/// Misurato il 29 agosto 2026 su un testo di storia romana, con lo stesso
/// testo per tutti e sette i formati:
///
/// | Formato | Senza tabelle | Con tabelle |
/// |---|---|---|
/// | Verifica equipollente | riesce in 9s, uscita pulita | fallisce dopo 54s |
/// | Formulario da banco    | riesce in 9s, uscita pulita | fallisce dopo 57s |
///
/// Erano gli unici due formati che chiedevano una tabella, ed erano gli unici
/// due che fallivano. Gli altri cinque riuscivano gia'.
final class LocalModelPromptTests: XCTestCase {

    /// I due formati che chiedevano una tabella non devono piu' chiederla al
    /// modello locale.
    func testNoFormatAsksTheLocalModelForATable() {
        for formato in DidacticFormat.allCases {
            let prompt = formato.systemPrompt(tablesSupported: false).lowercased()
            XCTAssertFalse(prompt.contains("tabella markdown"), "\(formato.rawValue) chiede ancora una tabella markdown")
            XCTAssertFalse(prompt.contains("tabelle a 2 colonne"), "\(formato.rawValue) chiede ancora tabelle")
        }
    }

    /// Ma a Gemini si continuano a chiedere, perche' le sa fare e nel
    /// documento Word diventano tabelle vere.
    func testTheCloudModelIsStillAskedForRealTables() {
        let equipollente = DidacticFormat.equipollenteExam.systemPrompt(tablesSupported: true)
        XCTAssertTrue(equipollente.contains("TABELLA markdown"),
                      "Rinunciare alle tabelle anche su Gemini peggiorerebbe la griglia di valutazione.")
        XCTAssertEqual(equipollente, DidacticFormat.equipollenteExam.systemPromptTemplate)
    }

    /// La griglia di valutazione e' un obbligo del D.I. 182/2020: puo'
    /// cambiare forma, non sparire.
    func testTheEvaluationGridSurvivesAsAList() {
        let prompt = DidacticFormat.equipollenteExam.systemPrompt(tablesSupported: false)
        XCTAssertTrue(prompt.contains("Griglia di Valutazione"))
        XCTAssertTrue(prompt.contains("elenco puntato"), prompt)
    }

    func testFormatsWithoutTablesAreUntouched() {
        for formato: DidacticFormat in [.conceptMap, .glossary, .clearExplanation, .interactiveQuiz, .pdpSummary] {
            XCTAssertEqual(formato.systemPrompt(tablesSupported: false), formato.systemPromptTemplate,
                           "\(formato.rawValue) non chiedeva tabelle: non c'era niente da cambiare.")
        }
    }

    /// Il prompt costruito davvero segue il motore, non un valore fisso.
    @MainActor
    func testTheBuiltPromptFollowsTheEngine() throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = AppViewModel(modelContext: ModelContext(container))
        viewModel.selectedFormat = .equipollenteExam
        viewModel.sourceText = "Il nome segreto di Roma era noto a pochi sacerdoti."
        let alunno = StudentProfile(name: "Paolo Gialli", classInfo: "3ª A")

        XCTAssertTrue(viewModel.buildPrompt(for: alunno, engine: .gemini).contains("TABELLA markdown"))
        XCTAssertFalse(viewModel.buildPrompt(for: alunno, engine: .systemModel).contains("TABELLA markdown"))
    }

    /// Il testo di partenza lungo e' gia' nel prompt: ripescarne i frammenti
    /// dall'indice spedirebbe due volte la stessa cosa.
    @MainActor
    func testALongSourceTextIsNotAlsoSentAsRetrievedContext() throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = AppViewModel(modelContext: ModelContext(container))
        let lezione = String(repeating: "Il nome segreto di Roma era noto a pochi sacerdoti. ", count: 40)
        viewModel.semanticSearch.indexRawText(text: lezione, title: "Lezione")
        viewModel.sourceText = lezione

        let prompt = viewModel.buildPrompt(for: StudentProfile(name: "Paolo Gialli", classInfo: "3ª A"))

        XCTAssertFalse(prompt.contains("CONTESTO DOCUMENTALE"),
                       "Con un testo lungo il recupero documentale ripete quello che c'è già.")
    }
}
