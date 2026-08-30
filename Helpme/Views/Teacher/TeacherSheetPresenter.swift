import SwiftUI

/// Presenta il pannello richiesto.
///
/// Esiste perché i pannelli servono da due punti diversi — la schermata
/// d'ingresso, quando non c'è ancora nessun alunno, e la barra laterale — e
/// duplicarli aveva già prodotto due pulsanti che non aprivano niente.
struct TeacherSheetPresenter: View {
    let sheet: TeacherSheet
    @Bindable var appViewModel: AppViewModel
    @Bindable var teacherViewModel: TeacherViewModel

    var body: some View {
        switch sheet {
        case .newStudent:
            StudentProfileModal(teacherViewModel: teacherViewModel)
        case .measures:
            if let student = appViewModel.selectedStudent {
                MeasuresChecklistModal(teacherViewModel: teacherViewModel, student: student)
            } else {
                missingStudent
            }
        case .quizBuilder:
            QuizBuilderModal(appViewModel: appViewModel)
        case .mindmapBuilder:
            MindmapBuilderModal(appViewModel: appViewModel)
        case .simplifier:
            SimplificationWorkbenchModal(appViewModel: appViewModel)
        case .gloDiary:
            GloDiaryModalView(teacherViewModel: teacherViewModel)
        case .schoolHeader:
            SchoolHeaderConfigModal(teacherViewModel: teacherViewModel)
        }
    }

    /// Meglio dirlo che aprire un pannello vuoto.
    private var missingStudent: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Seleziona prima una scheda alunno: le misure sono le sue.")
                .multilineTextAlignment(.center)
            Button("Chiudi") { teacherViewModel.activeSheet = nil }
                .buttonStyle(.borderedProminent)
                .tint(Color.institutional)
        }
        .padding(32)
        .frame(minWidth: 340)
    }
}
