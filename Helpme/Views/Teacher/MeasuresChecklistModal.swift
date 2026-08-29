import SwiftUI

/// Le misure del PDP dell'alunno, scelte da un catalogo invece che scritte
/// a mano.
///
/// Il testo di una misura compensativa è dicitura normativa: il Consiglio di
/// Classe la delibera e finisce nel fascicolo. Sceglierla da un elenco, e
/// vederne accanto la fonte, è più veloce che scriverla e non lascia spazio
/// a riformulazioni involontarie.
public struct MeasuresChecklistModal: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var teacherViewModel: TeacherViewModel

    private let student: StudentProfile
    @State private var selection: MeasureSelection

    public init(teacherViewModel: TeacherViewModel, student: StudentProfile) {
        self.teacherViewModel = teacherViewModel
        self.student = student
        _selection = State(initialValue: MeasureSelection.read(
            compensatory: student.compensatoryMeasures,
            dispensatory: student.dispensatoryMeasures
        ))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group(
                        "Strumenti compensativi",
                        caption: "Cosa si dà all'alunno perché possa fare la stessa cosa degli altri.",
                        measures: MeasureCatalog.compensative
                    )
                    group(
                        "Misure dispensative",
                        caption: "Da cosa si esonera l'alunno, perché non misura ciò che si vuole valutare.",
                        measures: MeasureCatalog.dispensative
                    )
                    if !selection.customMeasures.isEmpty { customSection }
                    derivedStrategies
                }
                .padding(.trailing, 6)
            }

            Divider()

            HStack {
                Button("Annulla") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Text("\(selection.selectedIds.count) misure scelte")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Salva misure") {
                    teacherViewModel.saveMeasures(selection, for: student)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.institutional)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.title)
                .foregroundColor(Color.institutional)
            VStack(alignment: .leading, spacing: 2) {
                Text("Misure PDP — \(student.name)")
                    .font(.title2).bold()
                Text("Diciture di L. 170/2010, D.M. 5669/2011 e D.I. 182/2020. Finiscono nella Scheda Sintesi PDP.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func group(_ title: String, caption: String, measures: [DidacticMeasure]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(measures) { measure in
                Toggle(isOn: Binding(
                    get: { selection.isSelected(measure) },
                    set: { _ in selection.toggle(measure) }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(measure.text)
                        Text(measure.reference)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    /// Le misure scritte a mano in schede compilate prima del catalogo. Si
    /// mostrano com'erano: se un docente ha annotato "Banco vicino alla
    /// cattedra", quella misura vale, e che il software non la conosca non è
    /// un problema suo.
    private var customSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Misure aggiunte a mano")
                .font(.headline)
            Text("Non sono nel catalogo: restano scritte come le hai messe tu.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(selection.customMeasures, id: \.self) { misura in
                HStack {
                    Text(misura)
                    Spacer()
                    Button {
                        selection.removeCustom(misura)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Togli questa misura")
                    .accessibilityLabel("Togli \(misura)")
                }
            }
        }
    }

    /// Non si spuntano: discendono da quello che hai già scelto. Mostrarle
    /// serve a far vedere che la scheda le dirà ai colleghi curricolari.
    private var derivedStrategies: some View {
        let lists = selection.lists()
        let strategie = PdpSheetComposer.assessmentStrategies(
            compensatory: lists.compensatory,
            dispensatory: lists.dispensatory
        )
        return VStack(alignment: .leading, spacing: 8) {
            Text("Strategie per le verifiche")
                .font(.headline)
            Text("Discendono dalle misure qui sopra: la scheda le riporta per i colleghi curricolari.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(strategie, id: \.self) { strategia in
                Label(strategia, systemImage: "arrow.turn.down.right")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
