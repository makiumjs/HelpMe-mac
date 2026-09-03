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
    @State private var newScore: String = ""
    @State private var newMinutesAllowed: Int? = nil
    @State private var newMinutesUsed: Int? = nil
    @State private var newNotes: String = ""
    @State private var copyConfirmation: String? = nil

    public init(teacherViewModel: TeacherViewModel) {
        self.teacherViewModel = teacherViewModel
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                        TextField("Esito / Punti (opzionale):", text: $newScore)
                            .frame(maxWidth: 180)
                    }

                    HStack(spacing: 10) {
                        Label("Tempi prova:", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Concessi (min)", value: $newMinutesAllowed, format: .number)
                            .frame(width: 105)
                        Text("vs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Effettivi usati (min)", value: $newMinutesUsed, format: .number)
                            .frame(width: 125)

                        if let allowed = newMinutesAllowed, let used = newMinutesUsed, allowed > 0 {
                            let pct = Int((Double(used) / Double(allowed) * 100).rounded())
                            Text("(\(pct)% del tempo concesso)")
                                .font(.caption)
                                .bold()
                                .foregroundColor(pct <= 100 ? Color.institutional : Color.orange)
                        }
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
                                notes: newNotes,
                                score: newScore,
                                minutesAllowed: newMinutesAllowed,
                                minutesUsed: newMinutesUsed
                            )
                            showNewEntryForm = false
                            newTopic = ""
                            newScore = ""
                            newMinutesAllowed = nil
                            newMinutesUsed = nil
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
                                if !entry.score.isEmpty {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text("Esito: \(entry.score)")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(Color.institutional)
                                }
                                Spacer()
                                Text("Autonomia: \(entry.autonomyLevel)")
                                    .font(.caption)
                                    .italic()
                            }
                            if let timeRatio = entry.timeRatioFormatted {
                                HStack(spacing: 5) {
                                    Image(systemName: "timer")
                                        .font(.caption2)
                                        .foregroundColor(Color.institutional)
                                    Text(timeRatio)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
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
            HStack {
                if let confirmation = copyConfirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button(action: copyMonitoringReport) {
                    Label("Copia Relazione Monitoraggio GLO", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(teacherViewModel.appViewModel.selectedStudent == nil)

                Button("Chiudi") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 740, height: 580)
    }

    private func copyMonitoringReport() {
        guard let student = teacherViewModel.appViewModel.selectedStudent else { return }
        let entries = teacherViewModel.appViewModel.gloEntries.filter { $0.studentId == student.id }
        let report = GloReportComposer.compose(.init(
            instituteName: teacherViewModel.appViewModel.schoolInfo.instituteName,
            studentName: student.name,
            classInfo: student.classInfo,
            programTitle: student.programType.localizedTitle,
            compensatory: student.compensatoryMeasures,
            dispensatory: student.dispensatoryMeasures,
            entries: entries,
            schoolYear: teacherViewModel.appViewModel.schoolInfo.schoolYear
        ))
        Clipboard.copy(report)
        copyConfirmation = "Relazione monitoraggio copiata negli appunti!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            copyConfirmation = nil
        }
    }
}
