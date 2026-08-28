import SwiftUI

public struct GloDiaryModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var teacherViewModel: TeacherViewModel
    
    @State private var selectedDimensionFilter: PeiDimension? = nil
    @State private var showNewEntryForm: Bool = false
    
    @State private var newTopic: String = ""
    @State private var newFormat: String = "Verifica Equipollente"
    @State private var newDimension: PeiDimension = .cognitive
    @State private var newAutonomy: String = "Autonomia con supporto visivo iniziale"
    @State private var newNotes: String = ""
    
    public init(teacherViewModel: TeacherViewModel) {
        self.teacherViewModel = teacherViewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "book.pages.fill")
                    .font(.title)
                    .foregroundColor(Color.institutional)
                
                VStack(alignment: .leading) {
                    Text("Registro & Diario di Bordo GLO")
                        .font(.title2)
                        .bold()
                    Text("Strutturato sulle 4 Dimensioni Ministeriali (D.I. 182/2020)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showNewEntryForm.toggle() }) {
                    Label("Nuova Voce", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.institutional)
            }
            
            Divider()
            
            // Filtri Dimensioni Ministeriali
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: { selectedDimensionFilter = nil }) {
                        Text("Tutte le Dimensioni")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedDimensionFilter == nil ? Color.institutional : Color.secondary.opacity(0.15))
                            .foregroundColor(selectedDimensionFilter == nil ? .white : .primary)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(PeiDimension.allCases, id: \.self) { dim in
                        Button(action: { selectedDimensionFilter = dim }) {
                            HStack(spacing: 4) {
                                Image(systemName: dim.iconName)
                                Text(dim.shortLabel)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedDimensionFilter == dim ? Color.institutional : Color.secondary.opacity(0.15))
                            .foregroundColor(selectedDimensionFilter == dim ? .white : .primary)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Form Nuova Voce se attiva
            if showNewEntryForm {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aggiungi Nota nel Registro GLO")
                        .font(.subheadline)
                        .bold()
                    
                    TextField("Argomento Trattato:", text: $newTopic)
                    
                    HStack {
                        Picker("Dimensione PEI:", selection: $newDimension) {
                            ForEach(PeiDimension.allCases, id: \.self) { dim in
                                Text(dim.shortLabel).tag(dim)
                            }
                        }
                        
                        TextField("Livello Autonomia:", text: $newAutonomy)
                    }
                    
                    TextField("Osservazioni per il GLO / Consiglio di Classe:", text: $newNotes)
                    
                    HStack {
                        Spacer()
                        Button("Annulla") { showNewEntryForm = false }
                        Button("Salva Voce") {
                            guard let student = teacherViewModel.appViewModel.selectedStudent else { return }
                            teacherViewModel.addGloEntry(
                                student: student,
                                topic: newTopic,
                                format: newFormat,
                                dimension: newDimension,
                                autonomy: newAutonomy,
                                notes: newNotes
                            )
                            showNewEntryForm = false
                            newTopic = ""
                            newNotes = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.institutional)
                        .disabled(newTopic.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
            
            // Elenco Voci Diario
            List {
                let filtered = teacherViewModel.appViewModel.gloEntries.filter { entry in
                    if let filter = selectedDimensionFilter {
                        return entry.dimension == filter
                    }
                    return true
                }
                
                if filtered.isEmpty {
                    Text("Nessuna voce registrata per questa dimensione.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(filtered) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: entry.dimension.iconName)
                                    .foregroundColor(Color.institutional)
                                Text(entry.dimension.rawValue)
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Color.institutional)
                                
                                Spacer()
                                
                                Text(entry.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(entry.topic)
                                .font(.headline)
                            
                            HStack {
                                Label(entry.formatUsed, systemImage: "doc.text.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Autonomia: \(entry.autonomyLevel)")
                                    .font(.caption)
                                    .italic()
                            }
                            
                            if !entry.notes.isEmpty {
                                Text(entry.notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button("Elimina voce", role: .destructive) {
                                teacherViewModel.deleteGloEntry(entry)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            
            // Footer
            HStack {
                Spacer()
                Button("Chiudi") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 720, height: 560)
    }
}
