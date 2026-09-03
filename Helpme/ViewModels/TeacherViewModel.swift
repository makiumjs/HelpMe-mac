import Foundation
import SwiftUI

public enum TeacherSheet: String, Identifiable, Sendable {
    case newStudent, measures, quizBuilder, mindmapBuilder, simplifier, gloDiary, schoolHeader
    public var id: String { rawValue }
}

@Observable
@MainActor
public final class TeacherViewModel {
    public var appViewModel: AppViewModel
    public var activeSheet: TeacherSheet? = nil
    public var showDocxExporter: Bool = false
    public var pendingDocument: DocxDocument? = nil
    public var suggestedFileName: String = "Documento"
    public var exportSuccessMessage: String? = nil
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
    public func saveMeasures(_ selection: MeasureSelection, for student: StudentProfile) {
        let lists = selection.lists()
        student.compensatoryMeasures = lists.compensatory
        student.dispensatoryMeasures = lists.dispensatory
        appViewModel.saveChanges()
    }

    // MARK: - Registro GLO
    public func addGloEntry(
        student: StudentProfile,
        topic: String,
        format: String,
        dimension: PeiDimension,
        autonomy: String,
        notes: String,
        score: String = "",
        minutesAllowed: Int? = nil,
        minutesUsed: Int? = nil
    ) {
        let entry = GloLogEntry(
            studentId: student.id,
            studentName: student.name,
            topic: topic,
            formatUsed: format,
            dimension: dimension,
            autonomyLevel: autonomy,
            notes: notes,
            score: score,
            minutesAllowed: minutesAllowed,
            minutesUsed: minutesUsed
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
            let cocoaError = error as NSError
            let userCancelled = cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError
            if !userCancelled {
                appViewModel.errorMessage = "Esportazione non riuscita: \(error.localizedDescription)"
            }
        }
    }
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
