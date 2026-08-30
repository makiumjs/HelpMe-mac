import XCTest
import SwiftData
@testable import Helpme

@MainActor
final class StudentProfileTests: XCTestCase {

    private func makeContext() -> ModelContext {
        ModelContext(PersistenceController(inMemory: true).container)
    }

    func testStudentProfileInitialization() {
        let student = StudentProfile(
            name: "Giulia Bianchi",
            classInfo: "4ª B Agrario",
            programType: .minimi,
            interest: "Robotica Agraria",
            notes: "Ottima memoria visiva."
        )

        XCTAssertEqual(student.name, "Giulia Bianchi")
        XCTAssertEqual(student.classInfo, "4ª B Agrario")
        XCTAssertEqual(student.programType, .minimi)
        XCTAssertTrue(student.programType.localizedTitle.contains("Obiettivi Minimi"))
        XCTAssertTrue(student.programType.legalReference.contains("D.I. 182/2020"))
    }

    func testDifferenziatoProgramType() {
        let student = StudentProfile(name: "Luca Verdi", classInfo: "2ª C", programType: .differenziato)
        XCTAssertEqual(student.programType, .differenziato)
        XCTAssertTrue(student.programType.localizedTitle.contains("Differenziata"))
    }

    func testProgramTypeSurvivesRoundTrip() {
        let student = StudentProfile(name: "Test", classInfo: "1ª A")
        student.programType = .differenziato
        XCTAssertEqual(student.programTypeRaw, "differenziato")
        XCTAssertEqual(student.programType, .differenziato)
    }

    /// La scheda deve sopravvivere alla chiusura dell'app: è il difetto
    /// principale della versione precedente, che teneva tutto in memoria.
    func testStudentIsPersistedAndRefetched() throws {
        let context = makeContext()
        let student = StudentProfile(
            name: "Marco Rossi",
            classInfo: "3ª A Agrario",
            programType: .minimi,
            interest: "Meccanica Agraria"
        )
        context.insert(student)
        try context.save()

        let refetched = try context.fetch(FetchDescriptor<StudentProfile>())
        XCTAssertEqual(refetched.count, 1)
        XCTAssertEqual(refetched.first?.name, "Marco Rossi")
        XCTAssertEqual(refetched.first?.programType, .minimi)
        // Le misure predefinite sono riferimenti al catalogo, non diciture
        // scritte a mano: cosi' il documento riporta le parole della norma.
        let misure = (refetched.first?.compensatoryMeasures ?? []) + (refetched.first?.dispensatoryMeasures ?? [])
        XCTAssertFalse(misure.isEmpty)
        for misura in misure {
            XCTAssertNotNil(MeasureCatalog.measure(id: misura), "\(misura) non e' nel catalogo")
        }
    }

    func testDeletingStudentAlsoRemovesGloEntries() throws {
        let context = makeContext()
        let viewModel = AppViewModel(modelContext: context)

        let student = StudentProfile(name: "Anna Neri", classInfo: "5ª A")
        viewModel.addStudent(student)
        viewModel.addGloEntry(GloLogEntry(
            studentId: student.id,
            studentName: student.name,
            topic: "Ciclo dell'azoto",
            formatUsed: "Mappa concettuale"
        ))
        XCTAssertEqual(viewModel.gloEntries.count, 1)

        viewModel.deleteStudent(student)

        XCTAssertTrue(viewModel.students.isEmpty)
        XCTAssertTrue(viewModel.gloEntries.isEmpty, "le voci GLO seguono la scheda eliminata")
        XCTAssertTrue(viewModel.hasNoStudents)
    }

    /// L'app non deve inventarsi voci di registro: il GLO è un documento
    /// ministeriale e lo compila il docente.
    func testGeneratingMaterialDoesNotWriteToGloRegister() async throws {
        let context = makeContext()
        let viewModel = AppViewModel(modelContext: context)
        viewModel.addStudent(StudentProfile(name: "Paolo Gialli", classInfo: "3ª B"))
        viewModel.selectedFormat = .equipollenteExam   // formato che passa da un motore
        viewModel.sourceText = "Il ciclo Otto a quattro tempi."

        // Nessun motore disponibile: niente chiamate vere, e soprattutto un
        // esito deterministico. Il registro GLO è un atto formale del docente
        // (vedi TeacherViewModel.addGloEntry): generare materiale non deve
        // scriverci dentro, né riuscendo né fallendo.
        viewModel.systemModelStatus = .appleIntelligenceOff
        await viewModel.generateMaterial()

        XCTAssertTrue(viewModel.gloEntries.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    /// Il modello integrato esaurisce il contesto *mentre scrive*, perché la
    /// sua finestra tiene testo di partenza e documento insieme. Successo
    /// misurato il 28 agosto 2026: due righe di testo, verifica equipollente,
    /// contesto pieno a metà documento. Se in quel caso l'app dice "accorcia
    /// il testo", manda il docente a tagliare una lezione già cortissima.
    func testRunningOutOfContextWhileWritingDoesNotBlameTheTeachersText() {
        let viewModel = AppViewModel(modelContext: makeContext())
        viewModel.selectedFormat = .equipollenteExam
        viewModel.generatedContent = "**VERIFICA DI MECCANICA AGRARIA**\n\n1. Descrivi il ciclo"

        let message = viewModel.failureMessage(for: SystemModelError.contextTooLong)

        XCTAssertTrue(message.contains("parte iniziale"),
                      "Va detto che il testo a schermo è monco: \(message)")
        XCTAssertTrue(message.contains("Gemini"),
                      "Va detta la via d'uscita vera: \(message)")
        XCTAssertFalse(message.contains("Accorcia il testo di partenza"),
                       "Consiglio inutile quando a sforare è l'uscita: \(message)")
    }

    /// A documento non ancora cominciato non sappiamo chi abbia sforato, e il
    /// messaggio generico — che nomina entrambe le cause — va bene.
    func testRunningOutOfContextBeforeWritingKeepsTheGeneralExplanation() {
        let viewModel = AppViewModel(modelContext: makeContext())

        let message = viewModel.failureMessage(for: SystemModelError.contextTooLong)

        XCTAssertEqual(message, SystemModelError.contextTooLong.errorDescription)
    }

    /// Su un Mac senza Apple Intelligence e senza chiave il pulsante di
    /// generazione deve spegnersi e spiegare perché, non fallire al click.
    func testWithoutAnyEngineTheTeacherIsToldWhyBeforeTrying() throws {
        let viewModel = AppViewModel(modelContext: makeContext())
        viewModel.selectedFormat = .interactiveQuiz   // generarlo richiede ancora un modello
        viewModel.systemModelStatus = .appleIntelligenceOff

        XCTAssertFalse(viewModel.canGenerate)
        let message = try XCTUnwrap(viewModel.engineRationale)
        XCTAssertTrue(message.contains("Gemini"), "Va detto come sbloccarsi: \(message)")
    }

    /// Ma la verifica equipollente, senza nessun motore, si costruisce lo
    /// stesso: i quesiti sono già quelli del docente curricolare.
    func testTheEquipollenteExamNoLongerNeedsAnEngineAtAll() throws {
        let viewModel = AppViewModel(modelContext: makeContext())
        viewModel.selectedFormat = .equipollenteExam
        viewModel.systemModelStatus = .appleIntelligenceOff
        viewModel.sourceText = "1. Prima domanda\n2. Seconda domanda"

        XCTAssertTrue(viewModel.canGenerate)
        let message = try XCTUnwrap(viewModel.engineRationale)
        XCTAssertTrue(message.contains("senza IA"), message)
    }
}
