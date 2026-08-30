import XCTest
import SwiftData
@testable import Helpme

/// Il formulario è uno strumento compensativo (L. 170/2010): sta sul banco
/// durante la lezione e la verifica, e vale se è corto. L'app propone, il
/// docente taglia.
final class DeskCardTests: XCTestCase {

    private let lezione = """
    La litosfera è lo strato rigido più esterno della Terra. Il movimento
    delle placche prende il nome di tettonica.

    La seconda legge della dinamica si scrive F = m · a. L'accelerazione di
    gravità vale 9,81 m/s² alla superficie terrestre.

    Ieri la classe ha svolto un'esercitazione in laboratorio.
    """

    private func entries() -> [DeskCardEntry] { DeskCardExtractor.extract(from: lezione) }

    func testFormulasDefinitionsAndDataAreToldApart() {
        let trovate = entries()

        XCTAssertTrue(trovate.contains { $0.kind == .formula && $0.text.contains("F = m · a") }, "\(trovate)")
        XCTAssertTrue(trovate.contains { $0.kind == .definition && $0.text.contains("litosfera") }, "\(trovate)")
        XCTAssertTrue(trovate.contains { $0.kind == .datum && $0.text.contains("9,81") }, "\(trovate)")
    }

    /// Una frase di cronaca non è materiale da banco.
    func testANarrativeSentenceIsNotPickedUp() {
        XCTAssertFalse(entries().contains { $0.text.contains("esercitazione in laboratorio") })
    }

    /// Il difetto trovato provando: un testo copiato da un libro va a capo
    /// dove finisce la riga, non dove finisce la frase, e uscivano voci come
    /// «delle placche prende il nome di tettonica».
    func testEntriesAreWholeSentencesNotLineFragments() {
        for entry in entries() {
            XCTAssertFalse(entry.text.hasPrefix("delle "), "Frase tagliata: «\(entry.text)»")
            let first = try! XCTUnwrap(entry.text.first)
            XCTAssertTrue(first.isUppercase || first == "L" || first == "È",
                          "Comincia a metà frase: «\(entry.text)»")
        }
        XCTAssertTrue(entries().contains { $0.text == "Il movimento delle placche prende il nome di tettonica." },
                      "\(entries().map(\.text))")
    }

    /// Le formule vanno per prime: sono quello che si cerca più in fretta
    /// durante una prova.
    func testFormulasComeFirst() {
        XCTAssertEqual(entries().first?.kind, .formula)
    }

    // MARK: - Riconoscimento

    func testAnEqualsSignAloneIsNotEnough() {
        XCTAssertFalse(DeskCardExtractor.isFormula("= 5"))
        XCTAssertTrue(DeskCardExtractor.isFormula("P = F / A"))
        XCTAssertTrue(DeskCardExtractor.isFormula("La pressione si calcola come P = F / A."))
    }

    func testTheDefinitionMarkersAreRecognised() {
        XCTAssertTrue(DeskCardExtractor.isDefinition("Il magma che esce si chiama lava."))
        XCTAssertTrue(DeskCardExtractor.isDefinition("La litosfera è lo strato rigido esterno."))
    }

    /// Un soggetto lungo racconta un fatto, non definisce.
    func testALongSubjectWithEssereIsNotADefinition() {
        XCTAssertFalse(DeskCardExtractor.isDefinition(
            "Il terremoto che nel 1906 colpì la città di San Francisco è ricordato ancora oggi."))
    }

    func testANumberWithoutAUnitIsNotADatum() {
        XCTAssertFalse(DeskCardExtractor.isDatum("Nel 1906 ci fu un terremoto."))
        XCTAssertTrue(DeskCardExtractor.isDatum("La densità è di 0,84 kg/l."))
    }

    // MARK: - Il documento

    func testTheSheetGroupsTheEntriesAndRecallsItsPurpose() {
        let scheda = DeskCardComposer.compose(entries: entries())

        XCTAssertTrue(scheda.contains("### Formule"))
        XCTAssertTrue(scheda.contains("### Definizioni da ricordare"))
        XCTAssertTrue(scheda.contains("L. 170/2010"))
        XCTAssertTrue(scheda.localizedCaseInsensitiveContains("vale se è corto"),
                      "Va ricordato che tagliare è il lavoro.")
    }

    func testATextWithoutMaterialSaysSoInsteadOfInventing() {
        let scheda = DeskCardComposer.compose(entries: [])
        XCTAssertTrue(scheda.contains("Non ho riconosciuto"), scheda)
    }

    // MARK: - Nell'app

    @MainActor
    func testTheSheetIsBuiltWithNoEngine() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.selectedFormat = .deskCheatSheet
        vm.sourceText = lezione

        XCTAssertTrue(vm.canGenerate)
        await vm.generateMaterial()

        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.generatedContent.contains("F = m · a"), vm.generatedContent)
    }

    /// Il glossario, che condivide lo stesso percorso, non deve essere finito
    /// nel formulario per sbaglio.
    @MainActor
    func testTheGlossaryStillProducesAGlossary() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.selectedFormat = .glossary
        vm.sourceText = lezione

        await vm.generateMaterial()

        XCTAssertTrue(vm.generatedContent.contains("Glossario"), vm.generatedContent)
        XCTAssertFalse(vm.generatedContent.contains("Formulario"))
    }
}
