import Foundation
import SwiftUI
import SwiftData
@Observable
@MainActor
public final class AppViewModel {

    // MARK: - Archivio

    private let modelContext: ModelContext

    public private(set) var students: [StudentProfile] = []
    public private(set) var gloEntries: [GloLogEntry] = []
    public var schoolInfo: SchoolInfo

    public var selectedStudent: StudentProfile? {
        didSet {
            guard selectedStudent !== oldValue else { return }
            if let previous = oldValue { store(into: previous) }
            restoreWork(of: selectedStudent)
        }
    }
    public func rememberWork() {
        guard let student = selectedStudent else { return }
        store(into: student)
    }
    private func store(into student: StudentProfile) {
        guard student.lastSourceText != sourceText
                || student.lastGeneratedContent != generatedContent else { return }

        student.lastSourceText = sourceText
        student.lastGeneratedContent = generatedContent
        if selectedFormat == .glossary,
           !GlossaryReader.definitions(from: generatedContent).isEmpty {
            student.personalGlossary = generatedContent
        }
        persist()
    }

    private func restoreWork(of student: StudentProfile?) {
        sourceText = student?.lastSourceText ?? ""
        generatedContent = student?.lastGeneratedContent ?? ""
    }
    // MARK: - Accessibilità
    public var accessibilitySettings: AccessibilitySettings {
        didSet { if accessibilitySettings != oldValue { SettingsStore.save(accessibilitySettings) } }
    }

    // MARK: - Configurazione riservata
    public let adminLock = AdminLock()

    public var selectedFormat: DidacticFormat {
        didSet { SettingsStore.save(lastFormat: selectedFormat) }
    }
    // MARK: - Licenza

    public internal(set) var licenseState: LicenseState = LicenseVerifier.verify(
        token: SettingsStore.loadLicenseToken() ?? ""
    )
    public func refreshLicenseState() {
        licenseState = LicenseVerifier.verify(token: SettingsStore.loadLicenseToken() ?? "")
    }
    @discardableResult
    public func activate(licenseToken: String) -> LicenseState {
        let state = LicenseVerifier.verify(token: licenseToken)
        if case .valid = state { SettingsStore.save(licenseToken: licenseToken) }
        licenseState = state
        return state
    }
    public var formatRationale: String? {
        if let licenseProblem = LicenseGate.explanation(licenseState) { return licenseProblem }
        switch selectedFormat {
        case .pdpSummary:
            return "Si compila dalle misure registrate nella scheda dell'alunno, "
                 + "con le diciture della normativa."
        case .equipollenteExam:
            return "Incolla la verifica della classe con i quesiti numerati: l'app la ricostruisce — "
                 + "tempo maggiorato, strumenti concessi, spazio per scrivere e griglia. "
                 + "La scomposizione guidata la aggiungi tu."
        case .deskCheatSheet:
            return "Cerca formule, definizioni e dati nel testo. Poi taglia: "
                 + "un formulario da banco vale se è corto."
        case .clearExplanation:
            return "Rende il testo leggibile e misura dov'è difficile con l'indice Gulpease. "
                 + "Le frasi da riscrivere te le indica: riscriverle resta a te, "
                 + "perché richiede di sapere quali parole l'alunno ha già."
        case .glossary:
            return "Estrae i termini dal testo, con la frase in cui compaiono. "
                 + "Le definizioni le scrivi tu."
        case .conceptMap:
            return "La mappa si costruisce, non si deduce da un testo: aprila con «Costruisci mappa» "
                 + "nella colonna a sinistra."
        case .interactiveQuiz:
            return "Il quiz si scrive: aprilo con «Scrivi il quiz» nella colonna a sinistra."
        }
    }

    public var canGenerate: Bool {
        guard LicenseGate.canGenerate(licenseState) else { return false }
        switch selectedFormat.localComposition {
        case .always:
            return true
        case .fromStructuredText, .fromAnyText:
            return !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .builtByTeacher:
            return false
        }
    }

    // MARK: - Editor
    static let editorFillLimit = 50_000
    public var sourceText: String = ""

    public var generatedContent: String = ""
    public var isGenerating: Bool = false
    public var errorMessage: String? = nil
    public var statusMessage: String? = nil

    public private(set) var isImportingDocuments: Bool = false
    public var hasNoStudents: Bool { students.isEmpty }

    // MARK: - Servizi
    public let audioReader: AudioReaderService
    public let documentReader: DocumentIndexer
    public let docxExporter: DocxExportService
    public let dictation: SpeechDictationService
    // MARK: - Inizializzazione
    public init(
        modelContext: ModelContext,
        audioReader: AudioReaderService? = nil,
        documentReader: DocumentIndexer? = nil,
        docxExporter: DocxExportService? = nil
    ) {
        self.modelContext = modelContext
        self.audioReader = audioReader ?? AudioReaderService()
        self.documentReader = documentReader ?? DocumentIndexer()
        self.docxExporter = docxExporter ?? DocxExportService()
        self.dictation = SpeechDictationService()
        self.schoolInfo = PersistenceController.loadOrCreateSchoolInfo(in: modelContext)
        self.accessibilitySettings = SettingsStore.loadAccessibilitySettings()
        self.selectedFormat = SettingsStore.loadLastFormat()
        KeychainStore.delete(.legacyApiKey)

        reloadFromStore()
        self.selectedStudent = students.first
        restoreWork(of: self.selectedStudent)
    }

    // MARK: - Lettura dall'archivio
    public func reloadFromStore() {
        let studentDescriptor = FetchDescriptor<StudentProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        students = (try? modelContext.fetch(studentDescriptor)) ?? []

        let gloDescriptor = FetchDescriptor<GloLogEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        gloEntries = (try? modelContext.fetch(gloDescriptor)) ?? []
    }
    private func persist() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Impossibile salvare sul disco: \(error.localizedDescription)"
        }
    }
    public func saveChanges() {
        persist()
        reloadFromStore()
    }

    // MARK: - Alunni

    public func addStudent(_ student: StudentProfile) {
        modelContext.insert(student)
        persist()
        reloadFromStore()
        selectedStudent = student
    }
    public func deleteStudent(_ student: StudentProfile) {
        let removedId = student.id
        modelContext.delete(student)
        for entry in gloEntries where entry.studentId == removedId {
            modelContext.delete(entry)
        }

        persist()
        reloadFromStore()
        if selectedStudent == nil || selectedStudent?.id == removedId {
            selectedStudent = students.first
        }
    }

    public func updateStudent(_ change: () -> Void) {
        change()
        persist()
        reloadFromStore()
    }

    // MARK: - Registro GLO

    public func addGloEntry(_ entry: GloLogEntry) {
        modelContext.insert(entry)
        persist()
        reloadFromStore()
    }

    public func deleteGloEntry(_ entry: GloLogEntry) {
        modelContext.delete(entry)
        persist()
        reloadFromStore()
    }

    // MARK: - Intestazione scuola

    public func saveSchoolInfo() {
        persist()
    }

    // MARK: - Importazione di documenti
    public func importDocuments(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isImportingDocuments = true
        errorMessage = nil
        statusMessage = nil

        let reader = documentReader
        var imported: [(title: String, text: String)] = []
        var failures: [String] = []

        for url in urls {
            do {
                let text = try await Task.detached(priority: .userInitiated) {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    return try reader.extractText(from: url)
                }.value
                imported.append((url.deletingPathExtension().lastPathComponent, text))
            } catch {
                failures.append("\(url.lastPathComponent) — \(error.localizedDescription)")
            }
        }

        isImportingDocuments = false

        if !imported.isEmpty {
            let body = imported.count == 1
                ? imported[0].text
                : imported.map { "## \($0.title)\n\n\($0.text)" }.joined(separator: "\n\n")
            let separator = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ""
                : "\n\n"
            sourceText = String((sourceText + separator + body).prefix(Self.editorFillLimit))

            let names = imported.map(\.title).joined(separator: ", ")
            statusMessage = "«\(names)» "
                + (imported.count == 1 ? "è ora" : "sono ora")
                + " nell'editor. Modifica pure il testo prima di generare."
        }

        if !failures.isEmpty {
            errorMessage = failures.count == 1
                ? "Non è stato possibile leggere \(failures[0])"
                : "Non è stato possibile leggere \(failures.count) file:\n• " + failures.joined(separator: "\n• ")
        }
    }

    // MARK: - Dettatura
    private var dictationBaseText: String = ""

    public var isDictating: Bool { dictation.isRecording }

    public func toggleDictation() async {
        dictation.isRecording ? stopDictation() : await startDictation()
    }
    public func startDictation() async {
        dictationBaseText = sourceText
        errorMessage = nil
        statusMessage = nil
        await dictation.start()
        if let message = dictation.errorMessage { errorMessage = message }
    }
    public func applyLiveDictation() {
        let transcript = dictation.liveTranscript
        guard !transcript.isEmpty else { return }
        sourceText = SpeechDictationService.merged(existing: dictationBaseText, dictated: transcript)
    }
    public func stopDictation() {
        dictation.stop()
        applyLiveDictation()
        let dictated = dictation.consumeTranscript()
        dictationBaseText = ""

        if let message = dictation.errorMessage {
            errorMessage = message
        } else if !dictated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            statusMessage = "Dettatura inserita nell'editor."
        }
    }

    // MARK: - Generazione del materiale didattico
    public func generateMaterial() async {
        guard let student = selectedStudent else {
            errorMessage = "Seleziona prima una scheda alunno."
            return
        }

        guard LicenseGate.canGenerate(licenseState) else {
            errorMessage = LicenseGate.explanation(licenseState)
            return
        }

        switch selectedFormat.localComposition {
        case .always:
            composeLocally(for: student)

        case .builtByTeacher:
            errorMessage = selectedFormat == .interactiveQuiz
                ? "Il quiz non si ricava da un testo: lo scrivi tu con «Scrivi il quiz», "
                  + "nella colonna a sinistra."
                : "La mappa non si ricava da un testo: la costruisci tu con «Costruisci mappa», "
                  + "nella colonna a sinistra."
            return

        case .fromAnyText, .fromStructuredText:
            guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Inserisci il testo base della lezione o della verifica curricolare."
                return
            }
            guard !SourceTextCheck.looksLikeAnInstruction(sourceText) else {
                errorMessage = SourceTextCheck.instructionExplanation(for: sourceText)
                return
            }

            if selectedFormat.localComposition == .fromStructuredText {
                let exam = ExamParser.parse(sourceText)
                guard !exam.isEmpty else {
                    errorMessage = "Non ho riconosciuto quesiti numerati in questo testo, quindi non posso "
                        + "ricostruirlo. Incolla la verifica della classe con i quesiti numerati (1., 2., 3.)."
                    return
                }
                composeEquipollente(exam, for: student)
            } else {
                composeFromText(for: student)
            }
        }

        rememberWork()
    }

    public func applySimplifiedText(_ text: String, rewritten: Int, gulpease: Int) {
        guard LicenseGate.canGenerate(licenseState) else {
            errorMessage = LicenseGate.explanation(licenseState)
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        generatedContent = text
        selectedFormat = .clearExplanation
        errorMessage = nil
        statusMessage = rewritten == 0
            ? "Testo impaginato senza riscritture. Indice Gulpease \(gulpease)/100."
            : "\(Plural.it(rewritten, "frase riscritta", "frasi riscritte")) da te. "
              + "Indice Gulpease \(gulpease)/100."
        rememberWork()
    }
    public func applyMindmap(_ nodes: [MindmapNode]) {
        guard LicenseGate.canGenerate(licenseState) else {
            errorMessage = LicenseGate.explanation(licenseState)
            return
        }
        guard !nodes.isEmpty else { return }
        generatedContent = MindmapComposer.compose(nodes)
        selectedFormat = .conceptMap
        errorMessage = nil
        statusMessage = "Mappa pronta. Lo studente la trova navigabile nella sua scheda."
        rememberWork()
    }
    public func applyQuiz(_ questions: [QuizQuestion]) {
        guard LicenseGate.canGenerate(licenseState) else {
            errorMessage = LicenseGate.explanation(licenseState)
            return
        }
        guard !questions.isEmpty else { return }
        generatedContent = QuizComposer.compose(questions)
        selectedFormat = .interactiveQuiz
        rememberWork()
        errorMessage = nil
        statusMessage = "\(Plural.it(questions.count, "domanda pronta", "domande pronte")). "
            + "Lo studente le trova nella sua scheda, cliccabili."
    }
    private func composeFromText(for student: StudentProfile) {
        errorMessage = nil

        switch selectedFormat {
        case .glossary:
            let terms = GlossaryExtractor.extract(from: sourceText)
            generatedContent = GlossaryComposer.compose(terms: terms, interest: student.interest)
            statusMessage = terms.isEmpty
                ? nil
                : "\(Plural.it(terms.count, "termine trovato", "termini trovati")) nel testo. "
                  + "Togli quelli che non servono e scrivi le definizioni."

        case .clearExplanation:
            let glossario = GlossaryReader.definitions(from: student.personalGlossary)
            generatedContent = ClearTextComposer.compose(sourceText, glossary: glossario)
            let report = ReadabilityAnalyzer.analyze(sourceText)
            statusMessage = "Indice Gulpease \(report.gulpease)/100. "
                + "\(Plural.it(report.sentencesNeedingWork.count, "frase da riscrivere", "frasi da riscrivere")). "
                + "Il testo e' stato reso leggibile, non semplificato: quello resta a te."

        case .deskCheatSheet:
            let entries = DeskCardExtractor.extract(from: sourceText)
            generatedContent = DeskCardComposer.compose(entries: entries)
            statusMessage = entries.isEmpty
                ? nil
                : "\(Plural.it(entries.count, "voce trovata", "voci trovate")) nel testo. "
                  + "Il formulario vale se è corto: togli quello che l'alunno ha già acquisito."

        default:
            errorMessage = "Questo formato non si compone da qui."
        }
    }
    private func composeEquipollente(_ exam: ParsedExam, for student: StudentProfile) {
        errorMessage = nil
        generatedContent = EquipollenteComposer.compose(.init(
            studentName: student.name,
            classInfo: student.classInfo,
            programTitle: student.programType.localizedTitle,
            compensatory: student.compensatoryMeasures,
            dispensatory: student.dispensatoryMeasures,
            exam: exam
        ))

        let quesiti = Plural.it(exam.questions.count, "quesito", "quesiti")
        statusMessage = "Ricostruita da \(quesiti). Aggiungi tu la scomposizione guidata "
            + "dove serve: è la parte che richiede di conoscere l'alunno."
    }
    private func composeLocally(for student: StudentProfile) {
        errorMessage = nil
        switch selectedFormat {
        case .pdpSummary:
            generatedContent = PdpSheetComposer.compose(.init(
                studentName: student.name,
                classInfo: student.classInfo,
                programTitle: student.programType.localizedTitle,
                programReference: student.programType.legalReference,
                interest: student.interest,
                notes: student.notes,
                compensatory: student.compensatoryMeasures,
                dispensatory: student.dispensatoryMeasures
            ))
            statusMessage = "Scheda compilata dalle misure registrate per \(student.name)."
        default:
            errorMessage = "Questo formato non si compone da qui."
        }
    }
}
