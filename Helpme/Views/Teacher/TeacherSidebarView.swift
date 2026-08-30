import SwiftUI
import UniformTypeIdentifiers

public struct TeacherSidebarView: View {
    @Bindable public var appViewModel: AppViewModel
    @Bindable public var teacherViewModel: TeacherViewModel
    @State private var studentPendingDeletion: StudentProfile? = nil
    
    public init(appViewModel: AppViewModel, teacherViewModel: TeacherViewModel) {
        self.appViewModel = appViewModel
        self.teacherViewModel = teacherViewModel
    }
    
    public var body: some View {
        ScrollView {
            sidebarContent
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Alunni PEI / DSA", systemImage: "person.2.badge.gearshape.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.institutional)
                Spacer()
                Button(action: { teacherViewModel.activeSheet = .newStudent }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.institutional)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aggiungi nuova scheda alunno")
                .help("Crea un nuovo profilo studente PEI/DSA")
            }
            HStack(spacing: 6) {
                Picker("Alunno Attivo:", selection: $appViewModel.selectedStudent) {
                    ForEach(appViewModel.students) { student in
                        Text("\(student.name) (\(student.classInfo))").tag(Optional(student))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                if let student = appViewModel.selectedStudent {
                    Button(role: .destructive) {
                        studentPendingDeletion = student
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Elimina la scheda di \(student.name)")
                    .accessibilityLabel("Elimina la scheda alunno di \(student.name)")
                }
            }
            
            if let student = appViewModel.selectedStudent {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(Color.institutional)
                        Text(student.programType.localizedTitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.institutional)
                    }
                    
                    Text("Interesse per analogie: \(student.interest)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.institutional.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Label("Formato Didattico", systemImage: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.institutional)
                VStack(spacing: 2) {
                    ForEach(DidacticFormat.allCases, id: \.self) { format in
                        let isSelected = appViewModel.selectedFormat == format

                        Button {
                            appViewModel.selectedFormat = format
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: iconForFormat(format))
                                    .foregroundColor(isSelected ? Color.institutional : .secondary)
                                    .font(.system(size: 14))
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.title)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text(format.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? Color.institutional.opacity(0.12) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(format.title): \(format.subtitle)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            
            Divider()
            VStack(spacing: 10) {
                Button(action: { teacherViewModel.activeSheet = .measures }) {
                    Label("Misure PDP dell'alunno", systemImage: "checklist")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(teacherViewModel.appViewModel.selectedStudent == nil)
                .help("Strumenti compensativi e misure dispensative, dal catalogo normativo")

                Button(action: { teacherViewModel.activeSheet = .quizBuilder }) {
                    Label("Scrivi il quiz", systemImage: "checkmark.bubble")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .help("Scrive un quiz cliccabile senza passare dall'IA")

                Button(action: { teacherViewModel.activeSheet = .mindmapBuilder }) {
                    Label("Costruisci la mappa", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .help("Costruisce una mappa concettuale navigabile senza passare dall'IA")

                Button(action: { teacherViewModel.activeSheet = .simplifier }) {
                    Label("Semplifica il testo", systemImage: "text.badge.checkmark")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(appViewModel.sourceText.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Riscrive una per volta le frasi difficili del testo di partenza")

                Button(action: { teacherViewModel.activeSheet = .gloDiary }) {
                    Label("Registro GLO (4 Dimensioni)", systemImage: "book.pages.fill")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Apre il registro di bordo per le 4 dimensioni ministeriali D.I. 182/2020")
                
                Button(action: { teacherViewModel.activeSheet = .schoolHeader }) {
                    Label("Intestazione Scuola (.docx)", systemImage: "building.columns.fill")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Configura denominazione, plessi e codici meccanografici della scuola")
                
                Button(action: { teacherViewModel.prepareDocxExport() }) {
                    Label("Esporta Word Ufficiale", systemImage: "arrow.down.doc.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.institutional)
                .disabled(appViewModel.generatedContent.isEmpty)
        .fileExporter(
                    isPresented: $teacherViewModel.showDocxExporter,
                    document: teacherViewModel.pendingDocument,
                    contentType: .docx,
                    defaultFilename: teacherViewModel.suggestedFileName
                ) { result in
                    teacherViewModel.handleExportResult(result)
                }
                .accessibilityLabel("Esporta documento in Microsoft Word con intestazione ufficiale")
                
                if let msg = teacherViewModel.exportSuccessMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(msg)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                            .lineLimit(2)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .sheet(item: $teacherViewModel.activeSheet) { sheet in
            TeacherSheetPresenter(sheet: sheet,
                                  appViewModel: appViewModel,
                                  teacherViewModel: teacherViewModel)
        }
        .alert(
            "Eliminare la scheda di \(studentPendingDeletion?.name ?? "")?",
            isPresented: Binding(
                get: { studentPendingDeletion != nil },
                set: { if !$0 { studentPendingDeletion = nil } }
            ),
            presenting: studentPendingDeletion
        ) { student in
            Button("Elimina", role: .destructive) {
                teacherViewModel.deleteStudent(student)
                studentPendingDeletion = nil
            }
            Button("Annulla", role: .cancel) { studentPendingDeletion = nil }
        } message: { _ in
            Text("Verranno eliminate anche le voci del registro GLO collegate. L'operazione non è reversibile.")
        }
    }
    
    private func iconForFormat(_ format: DidacticFormat) -> String {
        switch format {
        case .equipollenteExam: return "doc.badge.gearshape.fill"
        case .deskCheatSheet: return "tablecells.fill"
        case .pdpSummary: return "list.bullet.clipboard.fill"
        case .conceptMap: return "point.3.filled.connected.trianglepath.dotted"
        case .glossary: return "character.book.closed.fill"
        case .clearExplanation: return "text.badge.checkmark"
        case .interactiveQuiz: return "questionmark.bubble.fill"
        }
    }
}
