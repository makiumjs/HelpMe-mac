import XCTest
import SwiftData
@testable import Helpme

/// La Scheda PDP è il primo formato tolto all'IA. Non per risparmiare: il
/// documento riepiloga misure deliberate dal Consiglio di Classe e finisce
/// nel fascicolo dell'alunno, e il suo valore sta nel dire ogni volta
/// esattamente le stesse parole della normativa.
final class PdpSheetComposerTests: XCTestCase {

    private func input(
        compensatory: [String] = ["comp.sintesi-vocale", "comp.formulari"],
        dispensatory: [String] = ["disp.tempi", "disp.ortografia"],
        notes: String = ""
    ) -> PdpSheetComposer.Input {
        .init(
            studentName: "Andrea Pirlo",
            classInfo: "1ITA",
            programTitle: ProgramType.minimi.localizedTitle,
            programReference: ProgramType.minimi.legalReference,
            interest: "Informatica e Gaming",
            notes: notes,
            compensatory: compensatory,
            dispensatory: dispensatory
        )
    }

    // MARK: - Il documento

    func testTheSheetNamesTheStudentTheClassAndTheLegalBasis() {
        let scheda = PdpSheetComposer.compose(input())

        XCTAssertTrue(scheda.contains("Andrea Pirlo"))
        XCTAssertTrue(scheda.contains("1ITA"))
        // Il testo coordinato, non il solo decreto del 2020: il D.I. 153/2023
        // lo ha corretto, e su un documento che entra nel fascicolo citare un
        // testo non piu' vigente e' un errore.
        XCTAssertTrue(scheda.contains("D.I. 182/2020"), scheda)
        XCTAssertTrue(scheda.contains("D.I. 153/2023"), "Manca il decreto correttivo: \(scheda)")
    }

    /// Il punto di tutto l'esercizio: la dicitura è quella della norma, non
    /// una parafrasi.
    /// "Tempi aggiuntivi" e' una misura dispensativa (Linee guida 4.4) anche
    /// quando il docente l'ha annotata fra i compensativi: sul documento va
    /// sotto la voce giusta.
    func testAMeasureIsFiledWhereTheLawPutsItNotWhereItWasStored() {
        let scheda = PdpSheetComposer.compose(input(
            compensatory: ["Tempo aggiuntivo +30%"],
            dispensatory: []
        ))
        let compensativi = scheda.range(of: "1. Strumenti compensativi")!
        let dispensative = scheda.range(of: "2. Misure dispensative")!
        let tempi = scheda.range(of: "Tempi aggiuntivi")!

        XCTAssertTrue(tempi.lowerBound > dispensative.lowerBound,
                      "I tempi aggiuntivi sono una misura dispensativa: \(scheda)")
        XCTAssertTrue(compensativi.lowerBound < dispensative.lowerBound)
    }

    func testMeasuresAppearWithTheirExactLegalWordingAndSource() {
        let scheda = PdpSheetComposer.compose(input())

        XCTAssertTrue(scheda.contains("Sintesi vocale per la lettura autonoma dei testi"), scheda)
        XCTAssertTrue(scheda.contains("Tempi aggiuntivi fino al 30% per le prove scritte"), scheda)
        XCTAssertTrue(scheda.contains("D.M. 5669/2011"), "Va citata la fonte: \(scheda)")
    }

    /// Lo stesso alunno, due compilazioni: devono essere identiche. È la
    /// proprietà che un modello linguistico non può dare.
    func testComposingTwiceGivesTheIdenticalDocument() {
        XCTAssertEqual(PdpSheetComposer.compose(input()), PdpSheetComposer.compose(input()))
    }

    func testAStudentWithNoMeasuresGetsAnHonestSheetNotAnEmptyOne() {
        let scheda = PdpSheetComposer.compose(input(compensatory: [], dispensatory: []))

        XCTAssertTrue(scheda.contains("Nessuno strumento compensativo"), scheda)
        XCTAssertTrue(scheda.contains("Nessuna misura dispensativa"), scheda)
    }

    // MARK: - Le strategie derivate

    func testStrategiesFollowFromTheMeasuresAlreadyChosen() {
        let scheda = PdpSheetComposer.compose(input(
            compensatory: ["comp.formulari"],
            dispensatory: ["disp.lettura-alta-voce"]
        ))

        XCTAssertTrue(scheda.contains("Lettura del testo della prova da parte del docente"),
                      "Chi è dispensato dalla lettura ad alta voce va aiutato a leggere la consegna: \(scheda)")
        XCTAssertTrue(scheda.contains("Uso di mappe, schemi e formulari durante la prova"), scheda)
    }

    /// Vale per chiunque abbia un PDP: una verifica a sorpresa annulla
    /// l'effetto di qualunque misura compensativa.
    func testScheduledAssessmentsAreAlwaysRecommended() {
        let strategie = PdpSheetComposer.assessmentStrategies(compensatory: [], dispensatory: [])
        XCTAssertTrue(strategie.contains("Verifiche e interrogazioni programmate e concordate"))
    }

    // MARK: - Il confine clinico

    /// Questa scheda la leggono i colleghi curricolari: hanno diritto di
    /// sapere come si insegna a questo alunno, nessun titolo per leggerne la
    /// diagnosi.
    func testClinicalReferencesInTheTeachersNotesDoNotReachTheSheet() {
        let scheda = PdpSheetComposer.compose(input(
            notes: "Diagnosi di dislessia con disortografia associata. Lavora bene con le mappe a colori."
        ))

        XCTAssertFalse(scheda.lowercased().contains("dislessia"), scheda)
        XCTAssertFalse(scheda.lowercased().contains("diagnosi"), scheda)
    }

    // MARK: - Le schede già esistenti

    /// Le schede create prima del catalogo hanno diciture scritte a mano: se
    /// non le riconoscessimo, il docente le vedrebbe sparire.
    func testFreeTextMeasuresFromOlderProfilesAreStillRecognised() {
        XCTAssertEqual(MeasureCatalog.matching("Tempo aggiuntivo +30%")?.id, "disp.tempi")
        XCTAssertEqual(MeasureCatalog.matching("Sintesi vocale / Lettore schermo")?.id, "comp.sintesi-vocale")
        XCTAssertEqual(MeasureCatalog.matching("Formulario e schede guida")?.id, "comp.formulari")
    }

    func testAnUnknownMeasureIsKeptVerbatimRatherThanDropped() {
        let scheda = PdpSheetComposer.compose(input(compensatory: ["Banco vicino alla cattedra"], dispensatory: []))
        XCTAssertTrue(scheda.contains("Banco vicino alla cattedra"),
                      "Una misura che il catalogo non conosce non va persa: \(scheda)")
    }

    func testCatalogIdsAreUnique() {
        let ids = MeasureCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Un id ripetuto farebbe spuntare la misura sbagliata.")
    }

    // MARK: - Nell'app

    /// Senza nessun motore e senza testo di partenza, questo formato deve
    /// comunque produrre il documento.
    @MainActor
    func testTheSheetIsProducedWithNoEngineAndNoSourceText() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.selectedFormat = .pdpSummary
        vm.sourceText = ""

        XCTAssertTrue(vm.canGenerate, "La scheda si compila dalle misure registrate, non da un testo.")
        await vm.generateMaterial()

        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.generatedContent.contains("Andrea Pirlo"), vm.generatedContent)
    }

    @MainActor
    func testTheTeacherIsToldWhereTheSheetComesFrom() throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.selectedFormat = .pdpSummary

        let riga = try XCTUnwrap(vm.formatRationale)
        XCTAssertTrue(riga.contains("misure registrate"), riga)
    }
}
