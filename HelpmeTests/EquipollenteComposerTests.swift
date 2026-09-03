import XCTest
import SwiftData
@testable import Helpme

/// La verifica equipollente ricostruita senza modello. I contenuti non si
/// riscrivono: l'equipollenza sta nel mantenere gli obiettivi della classe
/// (D.I. 182/2020 Art. 15). L'app fa il lavoro di segreteria.
final class EquipollenteComposerTests: XCTestCase {

    private let verifica = """
    VERIFICA DI MECCANICA AGRARIA

    PARTE PRIMA — Domande aperte

    1. Descrivi il ciclo di funzionamento di un motore a quattro tempi. (punti 5)
    2. Spiega la differenza tra ciclo Otto e ciclo Diesel. (punti 4)

    PARTE SECONDA — Problema

    3. Una trattrice da 90 kW lavora per 6 ore.
       a) Calcola la potenza erogata. (punti 2)
       b) Calcola il consumo in kg. (punti 2)

    Tempo a disposizione: 60 minuti.
    """

    private func compose(
        compensatory: [String] = ["comp.calcolatrice", "comp.formulari"],
        dispensatory: [String] = ["disp.tempi"]
    ) -> String {
        EquipollenteComposer.compose(.init(
            studentName: "Andrea Pirlo",
            classInfo: "1ITA",
            programTitle: ProgramType.minimi.localizedTitle,
            compensatory: compensatory,
            dispensatory: dispensatory,
            exam: ExamParser.parse(verifica)
        ))
    }

    // MARK: - Il tempo

    func testTheTimeIsExtendedByThirtyPercentAndRounded() {
        XCTAssertEqual(EquipollenteComposer.extendedMinutes(from: 60), 80)   // 78 → 80
        XCTAssertEqual(EquipollenteComposer.extendedMinutes(from: 50), 65)
        // 120 + 30% = 156, arrotondati per eccesso ai 5 minuti: l'errore di
        // arrotondamento va a favore dell'alunno, non contro.
        XCTAssertEqual(EquipollenteComposer.extendedMinutes(from: 120), 160)
    }

    func testTheExtendedTimeIsOnTheSheetWithItsReason() {
        let foglio = compose()

        XCTAssertTrue(foglio.contains("80 minuti"), foglio)
        XCTAssertTrue(foglio.contains("60 minuti della prova della classe"),
                      "Va detto da dove viene, o sembra un numero a caso: \(foglio)")
    }

    func testWhenTheClassExamHasNoDurationTheTeacherIsAskedForIt() {
        let senzaTempo = EquipollenteComposer.compose(.init(
            studentName: "A", classInfo: "1", programTitle: "P",
            compensatory: [], dispensatory: [],
            exam: ExamParser.parse("1. Prima domanda\n2. Seconda domanda")
        ))
        XCTAssertTrue(senzaTempo.contains("non indicava una durata"), senzaTempo)
    }

    // MARK: - I contenuti restano quelli della classe

    func testEveryQuestionOfTheClassExamIsThere() {
        let foglio = compose()

        XCTAssertTrue(foglio.contains("Descrivi il ciclo di funzionamento"))
        XCTAssertTrue(foglio.contains("Spiega la differenza tra ciclo Otto"))
        XCTAssertTrue(foglio.contains("Calcola la potenza erogata"))
    }

    func testTheSectionsOfTheClassExamAreKept() {
        let foglio = compose()
        XCTAssertTrue(foglio.contains("PARTE PRIMA"))
        XCTAssertTrue(foglio.contains("PARTE SECONDA"))
    }

    /// Il punteggio va in griglia, non accanto alla domanda: sul foglio di
    /// chi la sta svolgendo è una distrazione in più.
    func testPointsMoveFromTheQuestionsToTheGrid() {
        let foglio = compose()
        let corpo = String(foglio.prefix(foglio.range(of: "Griglia di valutazione")!.lowerBound.utf16Offset(in: foglio)))

        XCTAssertFalse(corpo.contains("(punti 5)"), corpo)
        XCTAssertTrue(foglio.contains("| 1 |"), "La griglia deve avere una riga per quesito: \(foglio)")
        XCTAssertTrue(foglio.contains("**Totale**"))
    }

    func testThereIsRoomToWriteAndMoreWhereTheQuestionIsWorthMore() {
        let foglio = compose()
        XCTAssertTrue(foglio.contains("______"), "Serve lo spazio per rispondere.")
    }

    // MARK: - Cosa vede l'alunno e cosa vedono i docenti

    /// Gli strumenti concessi stanno sul foglio dell'alunno: è una cosa che
    /// deve sapere lui, non solo chi sorveglia.
    func testTheToolsTheStudentMayUseAreOnTheStudentsSheet() {
        let foglio = compose()

        XCTAssertTrue(foglio.contains("Puoi usare durante la prova"), foglio)
        XCTAssertTrue(foglio.contains("Calcolatrice non programmabile"), foglio)
    }

    /// Ma le misure dispensative no: scrivere "dispensato dalla lettura ad
    /// alta voce" sul foglio di chi svolge la prova non gli serve a niente e
    /// lo marchia davanti ai compagni.
    func testDispensationsAreNotPrintedInTheStudentsPartOfTheSheet() {
        let foglio = compose(compensatory: ["comp.calcolatrice"], dispensatory: ["disp.lettura-alta-voce"])
        let intestazione = foglio.range(of: "Griglia di valutazione")!.lowerBound
        let parteAlunno = String(foglio[foglio.startIndex..<intestazione])

        XCTAssertFalse(parteAlunno.contains("Dispensa dalla lettura ad alta voce"), parteAlunno)
        XCTAssertTrue(foglio.contains("Dispensa dalla lettura ad alta voce"),
                      "Al Consiglio di Classe però va detto: \(foglio)")
    }

    // MARK: - Nell'app

    @MainActor
    func testTheSheetIsBuiltFromTheCurricularExam() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.selectedFormat = .equipollenteExam
        vm.sourceText = verifica

        XCTAssertTrue(vm.canGenerate)
        await vm.generateMaterial()

        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.generatedContent.contains("Verifica equipollente"), vm.generatedContent)
        XCTAssertTrue(vm.statusMessage?.contains("Ricostruita da") ?? false, vm.statusMessage ?? "nessuno")
    }

    /// Un testo che non è una verifica non deve produrre una finta verifica:
    /// va detto che non è stato riconosciuto niente.
    @MainActor
    func testProseWithoutQuestionsIsRefusedWithAnExplanation() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.selectedFormat = .equipollenteExam
        vm.sourceText = "Il nome segreto di Roma era noto a pochi sacerdoti e tenuto nascosto."

        await vm.generateMaterial()

        XCTAssertTrue(vm.generatedContent.isEmpty)
        let errore = try XCTUnwrap(vm.errorMessage)
        XCTAssertTrue(errore.contains("quesiti numerati"), errore)
    }
}
