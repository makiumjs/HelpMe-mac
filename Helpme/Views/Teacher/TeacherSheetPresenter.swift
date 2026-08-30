import SwiftUI
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
