import SwiftUI
import UniformTypeIdentifiers

public struct MainWorkspaceView: View {
    @State public var appViewModel: AppViewModel
    @State private var teacherViewModel: TeacherViewModel
    @State private var studentViewModel: StudentReaderViewModel
    @State private var selectedTab: WorkspaceTab = .editor
    @State private var justCopied = false
    @State private var showSettingsPopover: Bool = false
    @State private var showDocumentImporter: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let importableTypes: [UTType] = {
        var types: [UTType] = [.pdf, .plainText, .rtf, .epub]
        for ext in ["docx", "md", "markdown"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }()
    public enum WorkspaceTab: String, CaseIterable {
        case editor = "Docente: Editor & Generatore"
        case studentReader = "Studente: Lettura & Studio DSA"
    }
    public init(appViewModel: AppViewModel) {
        self._appViewModel = State(initialValue: appViewModel)
        self._teacherViewModel = State(initialValue: TeacherViewModel(appViewModel: appViewModel))
        self._studentViewModel = State(initialValue: StudentReaderViewModel(appViewModel: appViewModel))
    }
    public var body: some View {
        Group {
            if appViewModel.hasNoStudents {
                WelcomeView(
                    onCreateStudent: { teacherViewModel.activeSheet = .newStudent },
                    onConfigureSchool: { teacherViewModel.activeSheet = .schoolHeader }
                )
                .sheet(item: $teacherViewModel.activeSheet) { sheet in
                    TeacherSheetPresenter(sheet: sheet,
                                          appViewModel: appViewModel,
                                          teacherViewModel: teacherViewModel)
                }
            } else {
                workspace
            }
        }
        .themedApp(appViewModel.accessibilitySettings)
    }

    private var workspace: some View {
        NavigationSplitView {
            TeacherSidebarView(appViewModel: appViewModel, teacherViewModel: teacherViewModel)
                .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 340)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Picker("Modalità:", selection: $selectedTab) {
                        ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                    .accessibilityLabel("Selettore modalità di lavoro docente o studente")
                    
                    Spacer()
                    Button(action: { showSettingsPopover.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
                    .accessibilityLabel("Impostazioni di accessibilità DSA, carattere e licenza")
                    .popover(isPresented: $showSettingsPopover) {
                        accessibilitySettingsView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.appControlBackground)
                .overlay(Divider(), alignment: .bottom)
                switch selectedTab {
                case .editor:
                    editorWorkspaceView()
                case .studentReader:
                    StudentReaderView(appViewModel: appViewModel, studentViewModel: studentViewModel)
                }
            }
        }
    }
    
    // MARK: - Editor Workspace
    private func editorWorkspaceView() -> some View {
        AdaptiveHSplit {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label("Testo / Verifica Curricolare Base", systemImage: "doc.plaintext.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.institutional)
                    Spacer()
                    dictationButton
                    Button(action: { showDocumentImporter = true }) {
                        if appViewModel.isImportingDocuments {
                            HStack(spacing: 5) {
                                ProgressView().controlSize(.small)
                                Text("Lettura…")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                        } else {
                            Label("Importa", systemImage: "doc.badge.plus")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(appViewModel.isImportingDocuments)
                    .help("PDF, Word (.docx), EPUB, RTF o testo semplice")
                    .accessibilityHint("Apre il selettore di file: il testo del documento finisce nell'editor")

                }

                TextEditor(text: $appViewModel.sourceText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(13)
                    .overlay(alignment: .topLeading) {
                        if appViewModel.sourceText.isEmpty {
                            Text("Incolla qui la lezione o la verifica della classe da adattare.\n\nNon è una casella di richieste: questo è il testo di partenza. Con «Importa» il documento finisce direttamente qui.")
                                .font(.system(.callout, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .background(Color.appTextBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                appViewModel.isDictating ? Color.red.opacity(0.65) : Color.primary.opacity(0.1),
                                lineWidth: appViewModel.isDictating ? 2 : 1
                            )
                    )

                if appViewModel.isDictating {
                    dictationBanner
                }

                Button(action: {
                    Task {
                        await appViewModel.generateMaterial()
                    }
                }) {
                    HStack(spacing: 8) {
                        if appViewModel.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "doc.text.fill")
                        }
                        Text(appViewModel.isGenerating ? "Generazione in corso..." : "Genera Materiale Equipollente (D.I. 182/2020)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.institutional)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .keyboardShortcut("g", modifiers: .command)
                .disabled(appViewModel.isGenerating || !appViewModel.canGenerate)

                if let rationale = appViewModel.formatRationale {
                    Label(rationale, systemImage: appViewModel.canGenerate ? "info.circle" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(appViewModel.canGenerate ? Color.secondary : Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if let err = appViewModel.errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.top, 2)
                } else if let status = appViewModel.statusMessage {
                    Label(status, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(minWidth: 340)
            .fileImporter(
                isPresented: $showDocumentImporter,
                allowedContentTypes: Self.importableTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task { await appViewModel.importDocuments(urls: urls) }
                case .failure(let error):
                    appViewModel.errorMessage = "Selezione annullata o non riuscita: \(error.localizedDescription)"
                }
            }
            .onChange(of: appViewModel.dictation.liveTranscript) { _, _ in
                appViewModel.applyLiveDictation()
            }
        } trailing: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Materiale Didattico Inclusivo", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.institutional)
                    
                    Spacer()
                    Button(action: {
                        Clipboard.copy(appViewModel.generatedContent)
                        justCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            justCopied = false
                        }
                    }) {
                        Label(justCopied ? "Copiato" : "Copia",
                              systemImage: justCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(justCopied ? Color.institutional : .primary)
                    }
                    .buttonStyle(.bordered)
                    .disabled(appViewModel.generatedContent.isEmpty)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: justCopied)
                    .accessibilityLabel(justCopied ? "Copiato negli appunti" : "Copia il materiale negli appunti")
                }
                TextEditor(text: $appViewModel.generatedContent)
                    .font(.system(.body, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.appTextBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .padding(16)
            .frame(minWidth: 340)
        }
    }
    
    // MARK: - Dettatura

    private var dictationButton: some View {
        Button(action: {
            Task { await appViewModel.toggleDictation() }
        }) {
            Label(
                appViewModel.isDictating ? "Ferma dettatura" : "Detta",
                systemImage: appViewModel.isDictating ? "mic.fill" : "mic"
            )
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .symbolEffect(.pulse, isActive: appViewModel.isDictating)
        }
        .buttonStyle(.bordered)
        .tint(appViewModel.isDictating ? .red : Color.institutional)
        .disabled(!appViewModel.dictation.isSupported)
        .help(appViewModel.dictation.isSupported
              ? "Scrivi parlando: il riconoscimento resta sul dispositivo"
              : "Riconoscimento vocale italiano non disponibile su questo Mac")
        .accessibilityLabel(appViewModel.isDictating
                            ? "Ferma la dettatura vocale"
                            : "Avvia la dettatura vocale nell'editor")
    }

    private var dictationBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)
                .symbolEffect(.variableColor, isActive: true)
            Text(appViewModel.dictation.liveTranscript.isEmpty
                 ? "Sto ascoltando… parla pure."
                 : appViewModel.dictation.liveTranscript)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Fine") {
                Task { await appViewModel.toggleDictation() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dettatura in corso")
    }

    private func accessibilitySettingsView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "accessibility.fill")
                    .foregroundColor(Color.institutional)
                    .font(.title3)
                Text("Accessibilità DSA & Licenza")
                    .font(.headline)
                    .bold()
            }
            Divider()
            AdminConfigurationSection(appViewModel: appViewModel)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Label("Tipografia Inclusiva", systemImage: "textformat.size")
                    .font(.caption)
                    .bold()
                
                Picker("Carattere:", selection: $appViewModel.accessibilitySettings.fontFamily) {
                    ForEach(AccessibleFontFamily.allCases, id: \.self) { family in
                        Text(family.isAvailable ? family.displayName : "\(family.displayName) — non installato")
                            .tag(family)
                    }
                }
                .pickerStyle(.menu)
                Text(appViewModel.accessibilitySettings.fontFamily.explanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Il pistone scende e aspira la miscela.")
                    .font(appViewModel.accessibilitySettings.fontFamily.font(
                        size: CGFloat(appViewModel.accessibilitySettings.fontSize)))
                    .tracking(CGFloat(appViewModel.accessibilitySettings.letterSpacing))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(appViewModel.accessibilitySettings.theme.background)
                    .foregroundColor(appViewModel.accessibilitySettings.theme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityLabel("Anteprima del carattere selezionato")
                VStack(spacing: 6) {
                    HStack {
                        Text("Dimensione Font: \(Int(appViewModel.accessibilitySettings.fontSize))pt")
                            .font(.caption)
                        Spacer()
                    }
                    Slider(value: $appViewModel.accessibilitySettings.fontSize, in: 14...32, step: 1)
                }
                VStack(spacing: 6) {
                    HStack {
                        Text("Interlinea: \(Int(appViewModel.accessibilitySettings.lineSpacing))pt")
                            .font(.caption)
                        Spacer()
                    }
                    Slider(value: $appViewModel.accessibilitySettings.lineSpacing, in: 4...24, step: 2)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Label("Tema Visivo (Anti-Affaticamento)", systemImage: "paintpalette.fill")
                    .font(.caption)
                    .bold()
                
                Picker("Palette:", selection: $appViewModel.accessibilitySettings.theme) {
                    ForEach(ColorThemePreset.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Sillabe a colori alternati", isOn: $appViewModel.accessibilitySettings.syllableColorsEnabled)
                    .font(.caption)
                    .help("Colora una sillaba sì e una no, per non perdere il segno nelle parole lunghe")
                Toggle("Applica tema e carattere a tutta l'app", isOn: $appViewModel.accessibilitySettings.applyThemeToWholeApp)
                    .font(.caption)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
