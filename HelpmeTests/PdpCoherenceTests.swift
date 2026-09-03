import XCTest
import SwiftData
@testable import Helpme

final class PdpCoherenceTests: XCTestCase {

    // MARK: - 1. Tempi aggiuntivi

    func testMissingDurationWhenTimeExtensionIsActiveTriggersWarning() {
        let exam = ExamParser.parse("""
        Verifica di Storia
        1. Chi era Carlo Magno?
        2. Descrivi il Sacro Romano Impero.
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Andrea Pirlo",
            compensatory: [],
            dispensatory: [MeasureCatalog.dispensative.first { $0.id == "disp.tempi" }!.text]
        )

        XCTAssertTrue(notices.contains { $0.id == "pdp.missing-duration" && $0.severity == .warning })
        let notice = notices.first { $0.id == "pdp.missing-duration" }
        XCTAssertTrue(notice?.message.contains("Andrea Pirlo") == true)
        XCTAssertTrue(notice?.message.contains("+30%") == true)
    }

    func testDurationPresentWhenTimeExtensionIsActiveProducesNoWarning() {
        let exam = ExamParser.parse("""
        Verifica di Storia
        Durata della prova: 60 minuti.
        1. Chi era Carlo Magno?
        2. Descrivi il Sacro Romano Impero.
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Andrea Pirlo",
            compensatory: [],
            dispensatory: [MeasureCatalog.dispensative.first { $0.id == "disp.tempi" }!.text]
        )

        XCTAssertFalse(notices.contains { $0.id == "pdp.missing-duration" })
    }

    // MARK: - 2. Strumenti da banco

    func testMathExamWithoutCompensatoryToolsSuggestsThem() {
        let exam = ExamParser.parse("""
        Verifica di Fisica
        Durata: 60 minuti.
        1. Calcola la velocità media: spazio 120 km, tempo 2 ore.
        2. Risolvi l'equazione della forza: massa 10 kg, accelerazione 3 m/s².
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Giulia Bianchi",
            compensatory: [],
            dispensatory: []
        )

        XCTAssertTrue(notices.contains { $0.id == "pdp.no-compensatory-tools" && $0.severity == .suggestion })
    }

    func testMathExamWithCompensatoryToolsProducesNoSuggestion() {
        let exam = ExamParser.parse("""
        Verifica di Fisica
        Durata: 60 minuti.
        1. Calcola la velocità media: spazio 120 km, tempo 2 ore.
        2. Risolvi l'equazione della forza: massa 10 kg, accelerazione 3 m/s².
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Giulia Bianchi",
            compensatory: ["comp.formulari", "comp.calcolatrice"],
            dispensatory: []
        )

        XCTAssertFalse(notices.contains { $0.id == "pdp.no-compensatory-tools" })
    }

    // MARK: - 3. Conflitto mnemonico

    func testMnemonicRequirementConflictsWithDispensa() {
        let exam = ExamParser.parse("""
        Verifica di Geometria
        Durata: 45 minuti.
        1. Scrivi a memoria la formula dell'area del trapezio.
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Marco Rossi",
            compensatory: ["comp.formulari"],
            dispensatory: ["disp.memorizzazione"]
        )

        XCTAssertTrue(notices.contains { $0.id == "pdp.conflict.mnemonic" && $0.severity == .warning })
        let notice = notices.first { $0.id == "pdp.conflict.mnemonic" }
        XCTAssertTrue(notice?.message.contains("a memoria") == true)
    }

    func testMentalCalculationConflictsWithDispensa() {
        let exam = ExamParser.parse("""
        Verifica di Matematica
        Durata: 45 minuti.
        1. Calcola a mente il valore di 15 x 12.
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Marco Rossi",
            compensatory: ["comp.calcolatrice"],
            dispensatory: ["disp.memorizzazione"]
        )

        XCTAssertTrue(notices.contains { $0.id == "pdp.conflict.mnemonic" && $0.severity == .warning })
    }

    // MARK: - 4. Lettura ad alta voce & dettatura

    func testReadingAloudConflictDetectsViolation() {
        let exam = ExamParser.parse("""
        Verifica di Italiano
        Durata: 60 minuti.
        1. Leggi ad alta voce il brano di Dante e poi rispondi alle domande.
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Luca Verdi",
            compensatory: [],
            dispensatory: ["disp.lettura-alta-voce"]
        )

        XCTAssertTrue(notices.contains { $0.id == "pdp.conflict.reading-aloud" && $0.severity == .warning })
    }

    func testDictationConflictDetectsViolation() {
        let exam = ExamParser.parse("""
        Verifica di Francese
        Durata: 45 minuti.
        1. Scrivi sotto dettatura il testo ascoltato.
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Luca Verdi",
            compensatory: [],
            dispensatory: ["disp.dettatura"]
        )

        XCTAssertTrue(notices.contains { $0.id == "pdp.conflict.dictation" && $0.severity == .warning })
    }

    // MARK: - 5. Riduzione quantitativa

    func testHighTaskCountWithQuantitaDispensaTriggersSuggestion() {
        let exam = ExamParser.parse("""
        Verifica di Scienze
        Durata: 60 minuti.
        1. Quesito 1
        2. Quesito 2
        3. Quesito 3
        4. Quesito 4
        5. Quesito 5
        6. Quesito 6
        7. Quesito 7
        8. Quesito 8
        """)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Sara Neri",
            compensatory: [],
            dispensatory: ["disp.quantita"]
        )

        XCTAssertTrue(notices.contains { $0.id == "pdp.high-exercise-count" && $0.severity == .suggestion })
    }

    // MARK: - 6. Banco di tolleranza su verifica reale (Zero falsi positivi)

    func testRealExamWithCoherentPdpHasZeroFalseWarnings() {
        let verificaReale = """
        VERIFICA DI SCIENZE DELLA TERRA
        Classe 2ª B — 14 ottobre
        Durata della prova: 90 minuti. È consentito l'uso della calcolatrice.

        1. Che cos'è una placca litosferica?
        2. Elenca i tre tipi di margine fra due placche.
        3. Spiega perché la faglia di Sant'Andrea è considerata trasforme.
        4. Completa: il magma solidificato forma le rocce magmatiche.
        """

        let exam = ExamParser.parse(verificaReale)

        let notices = PdpCoherenceChecker.check(
            exam: exam,
            studentName: "Andrea Pirlo",
            compensatory: ["comp.calcolatrice", "comp.formulari", "comp.mappe"],
            dispensatory: ["disp.tempi", "disp.ortografia"]
        )

        let warnings = notices.filter { $0.severity == .warning }
        XCTAssertTrue(warnings.isEmpty, "Falsi positivi generati su una prova regolare: \(warnings)")
    }

    // MARK: - 7. Integrazione reattiva in AppViewModel

    @MainActor
    func testAppViewModelExposesCoherenceNoticesReactively() throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = AppViewModel(modelContext: ModelContext(container))
        let student = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        student.dispensatoryMeasures = ["disp.tempi"]
        vm.addStudent(student)
        vm.selectedFormat = .equipollenteExam
        vm.sourceText = "Verifica di Storia\n1. Chi era Carlo Magno?"

        XCTAssertEqual(vm.pdpCoherenceNotices.count, 1)
        XCTAssertEqual(vm.pdpCoherenceNotices.first?.id, "pdp.missing-duration")
    }
}
