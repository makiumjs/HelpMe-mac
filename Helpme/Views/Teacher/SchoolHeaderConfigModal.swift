import SwiftUI

public struct SchoolHeaderConfigModal: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var teacherViewModel: TeacherViewModel
    
    @State private var instituteName: String = ""
    @State private var subTypes: String = ""
    @State private var mechanographicCode: String = ""
    @State private var address: String = ""
    @State private var schoolYear: String = ""
    @State private var teacherName: String = ""
    
    public init(teacherViewModel: TeacherViewModel) {
        self.teacherViewModel = teacherViewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .font(.title)
                    .foregroundColor(Color.institutional)
                
                VStack(alignment: .leading) {
                    Text("Intestazione Istituzionale Scuola")
                        .font(.title2)
                        .bold()
                    Text("Configurazione per l'esportazione ufficiale in Microsoft Word (.docx)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            Form {
                TextField("Denominazione Istituto:", text: $instituteName)
                TextField("Indirizzi / Plessi:", text: $subTypes)
                TextField("Codici Meccanografici:", text: $mechanographicCode)
                TextField("Indirizzo e Recapiti:", text: $address)
                TextField("Anno Scolastico:", text: $schoolYear)
                TextField("Docente Referente / Sostegno:", text: $teacherName)
            }
            
            // Anteprima Grafica
            VStack(spacing: 4) {
                Text(instituteName.isEmpty ? "Denominazione Scuola" : instituteName)
                    .font(.headline)
                    .bold()
                    .foregroundColor(Color.institutional)
                Text(subTypes.isEmpty ? "Indirizzi di studio" : subTypes)
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
                Text("\(address) — Cod. Mecc: \(mechanographicCode)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Divider()
                    .background(Color.institutional)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)
            
            Spacer()
            
            HStack {
                Button("Annulla") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Salva Intestazione") {
                    teacherViewModel.appViewModel.schoolInfo.instituteName = instituteName
                    teacherViewModel.appViewModel.schoolInfo.subTypes = subTypes
                    teacherViewModel.appViewModel.schoolInfo.mechanographicCode = mechanographicCode
                    teacherViewModel.appViewModel.schoolInfo.address = address
                    teacherViewModel.appViewModel.schoolInfo.schoolYear = schoolYear
                    teacherViewModel.appViewModel.schoolInfo.teacherName = teacherName
                    teacherViewModel.appViewModel.saveSchoolInfo()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.institutional)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 580, height: 500)
        .onAppear {
            let current = teacherViewModel.appViewModel.schoolInfo
            instituteName = current.instituteName
            subTypes = current.subTypes
            mechanographicCode = current.mechanographicCode
            address = current.address
            schoolYear = current.schoolYear
            teacherName = current.teacherName
        }
    }
}
