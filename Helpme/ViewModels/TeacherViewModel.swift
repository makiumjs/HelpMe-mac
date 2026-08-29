import Foundation
import SwiftUI

@Observable
@MainActor
public final class TeacherViewModel {

    public var appViewModel: AppViewModel

    public var showNewStudentModal: Bool = false
    public var showGloDiaryModal: Bool = false
    public var showSchoolHeaderModal: Bool = false
    public var showMeasuresModal: Bool = false

    // Esportazione .docx tramite pannello "Salva con nome"
    public var showDocxExporter: Bool = false
    public var pendingDocument: DocxDocument? = nil
    public var suggestedFileName: String = "Documento"
    public var exportSuccessMessage: String? = nil

    /// Vero se il documento appena preparato porta in coda la chiave di
    /// correzione: il messaggio di conferma deve avvisare di non stampare
    /// l'ultima pagina insieme al resto.
    public private(set) var exportIncludesAnswerKey: Bool = false

    public init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    // MARK: - Alunni

    public func addNewStudent(name: String, classInfo: String, programType: ProgramType, interest: String, notes: String) {
        let student = StudentProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            classInfo: classInfo.trimmingCharacters(in: .whitespacesAndNewlines),
            programType: programType,
            interest: interest,
            notes: notes
        )
        appViewModel.addStudent(student)
    }

    public func deleteStudent(_ student: StudentProfile) {
        appViewModel.deleteStudent(student)
    }

    /// Registra le misure scelte per l'alunno.
    public func saveMeasures(_ selection: MeasureSelection, for student: StudentProfile) {
        let lists = selection.lists()
        student.compensatoryMeasures = lists.compensatory
        student.dispensatoryMeasures = lists.dispensatory
        appViewModel.saveChanges()
    }

    // MARK: - Registro GLO

    public func addGloEntry(student: StudentProfile, topic: String, format: String, dimension: PeiDimension, autonomy: String, notes: String) {
        let entry = GloLogEntry(
            studentId: student.id,
            studentName: student.name,
            topic: topic,
            formatUsed: format,
            dimension: dimension,
            autonomyLevel: autonomy,
            notes: notes
        )
        appViewModel.addGloEntry(entry)
    }

    public func deleteGloEntry(_ entry: GloLogEntry) {
        appViewModel.deleteGloEntry(entry)
    }

    // MARK: - Esportazione Word

    /// Prepara il documento e apre il pannello di salvataggio.
    public func prepareDocxExport() {
        guard let student = appViewModel.selectedStudent else {
            appViewModel.errorMessage = "Seleziona una scheda alunno prima di esportare."
            return
        }
        guard !appViewModel.generatedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appViewModel.errorMessage = "Non c'è ancora materiale da esportare."
            return
        }

        exportSuccessMessage = nil

        // Il documento esce dall'app e finisce in mano allo studente: le
        // risposte esatte vanno tolte dal corpo e spostate nella chiave di
        // correzione, che finisce su una pagina a sé — così il docente ce
        // l'ha, e gli basta non stampare l'ultima pagina.
        let raw = appViewModel.generatedContent
        let answerKey = StudyTextPresenter.answerKey(from: raw)

        let data = appViewModel.docxExporter.makeDocxData(
            schoolInfo: appViewModel.schoolInfo,
            student: student,
            format: appViewModel.selectedFormat,
            title: appViewModel.selectedFormat.title,
            content: StudyTextPresenter.handout(raw),
            answerKey: answerKey
        )

        exportIncludesAnswerKey = answerKey != nil

        pendingDocument = DocxDocument(data: data)
        suggestedFileName = Self.fileName(for: student, format: appViewModel.selectedFormat)
        showDocxExporter = true
    }

    public func handleExportResult(_ result: Result<URL, Error>) {
        pendingDocument = nil

        switch result {
        case .success(let url):
            exportSuccessMessage = exportIncludesAnswerKey
                ? "Documento salvato: \(url.lastPathComponent). L'ultima pagina è la chiave di correzione: non consegnarla."
                : "Documento salvato: \(url.lastPathComponent)"
        case .failure(let error):
            // L'annullamento del pannello non è un errore da mostrare.
            let cocoaError = error as NSError
            let userCancelled = cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError
            if !userCancelled {
                appViewModel.errorMessage = "Esportazione non riuscita: \(error.localizedDescription)"
            }
        }
    }

    /// "HelpMe_Marco_Rossi_Verifica_Equipollente" — senza caratteri che i
    /// filesystem non gradiscono.
    static func fileName(for student: StudentProfile, format: DidacticFormat) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        func slug(_ text: String) -> String {
            text.components(separatedBy: illegal).joined()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: "_")
        }
        let name = slug(student.name)
        let formatName = slug(format.title)
        return "HelpMe_\(name.isEmpty ? "Alunno" : name)_\(formatName)"
    }
}
