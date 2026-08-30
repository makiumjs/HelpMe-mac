import SwiftUI

/// Riscrive le frasi difficili, una per volta.
///
/// L'analizzatore dice *quali* frasi sono il problema; qui si riscrivono,
/// con l'originale sopra e l'indice che si muove mentre si lavora. Le frasi
/// che vanno bene non compaiono: il lavoro va dove serve.
public struct SimplificationWorkbenchModal: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var appViewModel: AppViewModel

    @State private var rows: [SimplificationRow]
    private let glossary: [String: String]
    private let startingIndex: Int

    public init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        let rows = SimplificationDraft.rows(from: appViewModel.sourceText)
        _rows = State(initialValue: rows)
        self.glossary = GlossaryReader.definitions(
            from: appViewModel.selectedStudent?.personalGlossary ?? "")
        self.startingIndex = SimplificationDraft.currentGulpease(rows)
    }

    private var toRewrite: [Int] { rows.indices.filter { rows[$0].reading.needsWork } }
    private var done: Int { toRewrite.filter { rows[$0].isRewritten }.count }
    private var currentIndex: Int { SimplificationDraft.currentGulpease(rows) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()

            if toRewrite.isEmpty {
                nothingToDo
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(toRewrite.enumerated()), id: \.element) { position, index in
                            sentenceEditor(index, number: position + 1)
                        }
                    }
                    .padding(.trailing, 6)
                }
            }

            Divider()
            footer
        }
        .padding(22)
        .frame(minWidth: 680, minHeight: 600)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.badge.checkmark")
                .font(.title)
                .foregroundColor(Color.institutional)
            VStack(alignment: .leading, spacing: 2) {
                Text("Semplifica il testo").font(.title2).bold()
                Text("Compaiono solo le frasi che pesano. Quelle che vanno bene restano come stanno.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            indexBadge
        }
    }

    /// L'indice si muove mentre si scrive: è il riscontro che dice se la
    /// riscrittura sta servendo davvero, invece di far riscrivere alla cieca.
    private var indexBadge: some View {
        VStack(spacing: 1) {
            Text("Gulpease")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                if currentIndex != startingIndex {
                    Text("\(startingIndex)")
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
                Text("\(currentIndex)")
                    .bold()
                    .foregroundStyle(currentIndex >= 60 ? Color.institutional : Color.orange)
            }
            .font(.system(size: 17, design: .rounded))
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Indice Gulpease: \(currentIndex) su 100, partiva da \(startingIndex)")
    }

    private var nothingToDo: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.largeTitle)
                .foregroundStyle(Color.institutional)
            Text(rows.isEmpty
                 ? "Incolla prima il testo da semplificare nell'editor."
                 : "Nessuna frase da riscrivere: il testo regge così com'è.")
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("Annulla") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            if !toRewrite.isEmpty {
                Text("\(done) di \(toRewrite.count) riscritte")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Metti nel materiale") {
                appViewModel.applySimplifiedText(SimplificationDraft.assemble(rows),
                                                 rewritten: done,
                                                 gulpease: currentIndex)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.institutional)
            .keyboardShortcut(.defaultAction)
            .disabled(rows.isEmpty)
        }
    }

    private func sentenceEditor(_ index: Int, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(number).")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(rows[index].reading.reasons.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(Color.orange)
                Spacer()
                if rows[index].isRewritten {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.institutional)
                        .font(.caption)
                }
            }

            Text(rows[index].original)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            TextField("Riscrivila con parole più semplici", text: $rows[index].rewritten, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            // Le parole che il docente ha già spiegato per questo alunno,
            // proprio accanto alla frase che le contiene.
            let aiuti = SimplificationDraft.hints(for: rows[index], glossary: glossary)
            if !aiuti.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(aiuti, id: \.0) { termine, definizione in
                        Text("**\(termine)** → \(definizione)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }
}
