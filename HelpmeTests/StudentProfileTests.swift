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
        viewModel.selectedFormat = .equipollenteExam
        viewModel.sourceText = "Il ciclo Otto a quattro tempi."

        // Il registro GLO è un atto formale del docente (vedi
        // TeacherViewModel.addGloEntry): generare materiale non deve
        // scriverci dentro, né riuscendo né fallendo.
        await viewModel.generateMaterial()

        XCTAssertTrue(viewModel.gloEntries.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    /// Il quiz non si ricava da un testo: il pulsante deve spegnersi e dire
    /// dove si scrive, non fallire al click.
    func testAFormatThatIsWrittenByTheTeacherSaysSoBeforeTrying() throws {
        let viewModel = AppViewModel(modelContext: makeContext())
        viewModel.selectedFormat = .interactiveQuiz

        XCTAssertFalse(viewModel.canGenerate)
        let message = try XCTUnwrap(viewModel.formatRationale)
        XCTAssertTrue(message.contains("Scrivi il quiz"), "Va detto dove si scrive: \(message)")
    }

    /// La verifica equipollente si costruisce dal testo del docente
    /// curricolare: i quesiti li ha già scelti lui.
    func testTheEquipollenteExamIsBuiltFromTheTeachersOwnText() throws {
        let viewModel = AppViewModel(modelContext: makeContext())
        viewModel.selectedFormat = .equipollenteExam
        viewModel.sourceText = "1. Prima domanda\n2. Seconda domanda"

        XCTAssertTrue(viewModel.canGenerate)
        let message = try XCTUnwrap(viewModel.formatRationale)
        XCTAssertTrue(message.contains("quesiti numerati"), message)
    }
}
