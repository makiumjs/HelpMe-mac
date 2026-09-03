import SwiftUI
public struct MindmapBuilderModal: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var appViewModel: AppViewModel
    @State private var rows: [MindmapDraftRow]
    public init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        // Si riapre solo su un markup che e' davvero una mappa: con una
        // Scheda PDP nell'editor, il parser ne prenderebbe i titoli come nodi.
        let existing = appViewModel.selectedFormat == .conceptMap
            ? MindmapParser.parse(appViewModel.generatedContent)
            : []
        _rows = State(initialValue: existing.isEmpty
            ? [MindmapDraftRow()]
            : MindmapDraft.rows(from: existing))
    }
    private var filled: Int { rows.filter(\.isFilled).count }
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array($rows.enumerated()), id: \.element.id) { index, $row in
                        rowEditor($row, at: index)
                    }
                }
                .padding(.trailing, 6)
            }
            HStack {
                Button {
                    rows.append(MindmapDraftRow(level: rows.last?.level ?? 0))
                } label: {
                    Label("Aggiungi una voce", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                if !appViewModel.sourceText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        seedFromSourceText()
                    } label: {
                        Label("Prendi i termini dal testo", systemImage: "text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .help("Aggiunge i termini tecnici trovati nel testo, da riordinare")
                }
            }
            Divider()
            footer
        }
        .padding(22)
        .frame(minWidth: 640, minHeight: 580)
    }
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.title)
                .foregroundColor(Color.institutional)
            VStack(alignment: .leading, spacing: 2) {
                Text("Costruisci la mappa").font(.title2).bold()
                Text("Una voce per riga. Le frecce spostano la voce dentro o fuori dal concetto che la precede.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    private var footer: some View {
        HStack {
            Button("Annulla") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Text("\(Plural.it(filled, "voce", "voci"))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Metti nel materiale") {
                appViewModel.applyMindmap(MindmapDraft.nodes(from: rows))
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.institutional)
            .keyboardShortcut(.defaultAction)
            .disabled(filled == 0)
        }
    }
    private func rowEditor(_ row: Binding<MindmapDraftRow>, at index: Int) -> some View {
        HStack(spacing: 6) {
            Spacer().frame(width: CGFloat(row.wrappedValue.level) * 26)
            Image(systemName: row.wrappedValue.level == 0 ? "circle.fill" : "arrow.turn.down.right")
                .font(.system(size: row.wrappedValue.level == 0 ? 7 : 10))
                .foregroundStyle(row.wrappedValue.level == 0 ? Color.institutional : .secondary)
                .frame(width: 14)
            TextField("Concetto", text: row.title)
                .textFieldStyle(.roundedBorder)
            TextField("Dettaglio o esempio (facoltativo)", text: row.detail)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .frame(maxWidth: 220)
            Button {
                rows[index].level -= 1
            } label: { Image(systemName: "arrow.left") }
                .buttonStyle(.plain)
                .disabled(row.wrappedValue.level == 0)
                .help("Porta fuori di un livello")
                .accessibilityLabel("Porta fuori di un livello")
            Button {
                rows[index].level += 1
            } label: { Image(systemName: "arrow.right") }
                .buttonStyle(.plain)
                .disabled(!MindmapDraft.canIndent(rows, at: index))
                .help("Porta dentro il concetto sopra")
                .accessibilityLabel("Porta dentro il concetto sopra")
            Button(role: .destructive) {
                rows.remove(at: index)
                if rows.isEmpty { rows = [MindmapDraftRow()] }
            } label: { Image(systemName: "trash") }
                .buttonStyle(.plain)
                .accessibilityLabel("Elimina questa voce")
        }
    }
    private func seedFromSourceText() {
        let esistenti = Set(rows.map { $0.title.lowercased() })
        let nuovi = GlossaryExtractor.extract(from: appViewModel.sourceText, limit: 10)
            .map(\.term)
            .filter { !esistenti.contains($0.lowercased()) }
            .map { MindmapDraftRow(title: $0.capitalizedFirstLetter, level: 1) }
        if rows.count == 1, !rows[0].isFilled { rows.removeAll() }
        rows.append(contentsOf: nuovi)
    }
}
