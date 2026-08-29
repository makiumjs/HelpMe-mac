import XCTest
import SwiftData
@testable import Helpme

/// La checklist esiste perché fino a ieri le misure di un alunno non erano
/// modificabili da nessuna parte dell'app: restavano quelle predefinite.
final class MeasureSelectionTests: XCTestCase {

    func testReadingASheetMarksTheMeasuresThatAreAlreadyThere() {
        let selezione = MeasureSelection.read(
            compensatory: ["comp.sintesi-vocale"],
            dispensatory: ["disp.tempi"]
        )

        XCTAssertEqual(selezione.selectedIds, ["comp.sintesi-vocale", "disp.tempi"])
        XCTAssertTrue(selezione.customMeasures.isEmpty)
    }

    /// Le schede compilate prima del catalogo hanno diciture scritte a mano:
    /// vanno riconosciute, o il docente crederebbe di aver perso tutto.
    func testHandWrittenMeasuresFromOlderSheetsAreRecognised() {
        let selezione = MeasureSelection.read(
            compensatory: ["Tempo aggiuntivo +30%", "Sintesi vocale / Lettore schermo"],
            dispensatory: []
        )

        XCTAssertTrue(selezione.selectedIds.contains("disp.tempi"))
        XCTAssertTrue(selezione.selectedIds.contains("comp.sintesi-vocale"))
    }

    /// Ma una misura che il catalogo non conosce non si butta via: se un
    /// docente ha scritto "Banco vicino alla cattedra", quella misura vale.
    func testAnUnknownMeasureIsKeptAsWritten() {
        var selezione = MeasureSelection.read(
            compensatory: ["Banco vicino alla cattedra"],
            dispensatory: []
        )

        XCTAssertEqual(selezione.customMeasures, ["Banco vicino alla cattedra"])
        XCTAssertTrue(selezione.lists().compensatory.contains("Banco vicino alla cattedra"))

        selezione.removeCustom("Banco vicino alla cattedra")
        XCTAssertTrue(selezione.customMeasures.isEmpty)
    }

    /// Aprire e salvare senza toccare niente non deve cambiare le misure.
    func testOpeningAndSavingWithoutChangesIsNotDestructive() {
        let comp = ["comp.sintesi-vocale", "Banco vicino alla cattedra"]
        let disp = ["disp.tempi"]

        let dopo = MeasureSelection.read(compensatory: comp, dispensatory: disp).lists()

        XCTAssertEqual(Set(dopo.compensatory), Set(comp))
        XCTAssertEqual(Set(dopo.dispensatory), Set(disp))
    }

    /// Salvando, ogni misura va nella lista che le assegna la normativa.
    func testSavingFilesEachMeasureWhereTheLawPutsIt() {
        var selezione = MeasureSelection()
        selezione.toggle(MeasureCatalog.measure(id: "disp.tempi")!)

        let liste = selezione.lists()

        XCTAssertTrue(liste.dispensatory.contains("disp.tempi"))
        XCTAssertFalse(liste.compensatory.contains("disp.tempi"),
                       "I tempi aggiuntivi sono una misura dispensativa, anche se spuntati altrove.")
    }

    func testTogglingTwiceLeavesNoTrace() {
        let misura = MeasureCatalog.measure(id: "comp.mappe")!
        var selezione = MeasureSelection()

        selezione.toggle(misura)
        XCTAssertTrue(selezione.isSelected(misura))
        selezione.toggle(misura)

        XCTAssertFalse(selezione.isSelected(misura))
        XCTAssertEqual(selezione, MeasureSelection())
    }

    /// Il giro completo: si sceglie, si salva sulla scheda, e la Scheda PDP
    /// riporta quello che si è scelto.
    @MainActor
    func testChosenMeasuresReachThePdpSheet() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let app = AppViewModel(modelContext: ModelContext(container))
        let teacher = TeacherViewModel(appViewModel: app)
        let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        app.addStudent(alunno)

        var selezione = MeasureSelection()
        selezione.toggle(MeasureCatalog.measure(id: "comp.dizionario")!)
        teacher.saveMeasures(selezione, for: alunno)

        app.selectedFormat = .pdpSummary
        await app.generateMaterial()

        XCTAssertTrue(app.generatedContent.contains("Dizionario digitale"), app.generatedContent)
        XCTAssertFalse(app.generatedContent.contains("Sintesi vocale"),
                       "Le misure predefinite erano state deselezionate: non devono ricomparire.")
    }
}
