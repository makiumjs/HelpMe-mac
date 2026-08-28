import SwiftUI

public struct StudentProfileModal: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var teacherViewModel: TeacherViewModel
    
    @State private var name: String = ""
    @State private var classInfo: String = ""
    @State private var programType: ProgramType = .minimi
    @State private var interest: String = "Informatica e Gaming"
    @State private var notes: String = ""
    
    public init(teacherViewModel: TeacherViewModel) {
        self.teacherViewModel = teacherViewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title)
                    .foregroundColor(Color.institutional)
                VStack(alignment: .leading) {
                    Text("Nuova Scheda Alunno")
                        .font(.title2)
                        .bold()
                    Text("Conformità D.I. 182/2020 & L. 170/2010")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            // Form
            Form {
                TextField("Nome e Cognome:", text: $name)
                TextField("Classe e Indirizzo:", text: $classInfo, prompt: Text("Es. 3ª A Agrario"))
                
                Picker("Tipologia Percorso PEI:", selection: $programType) {
                    ForEach(ProgramType.allCases, id: \.self) { type in
                        Text(type.localizedTitle).tag(type)
                    }
                }
                
                TextField("Interesse Primario (per analogie):", text: $interest, prompt: Text("Es. Meccanica, Calcio, Disegno..."))
                
                TextEditor(text: $notes)
                    .frame(height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                    .overlay(
                        Group {
                            if notes.isEmpty {
                                Text("Punti di forza, stile di apprendimento, misure compensative...")
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(8)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        }
                    )
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Annulla") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Salva Scheda Alunno") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    teacherViewModel.addNewStudent(
                        name: name,
                        classInfo: classInfo,
                        programType: programType,
                        interest: interest,
                        notes: notes
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.institutional)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520, height: 440)
    }
}
