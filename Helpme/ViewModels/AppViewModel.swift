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

    // MARK: - Configurazione IA
    public let adminLock = AdminLock()
    public private(set) var geminiApiKey: String
    public var hasGeminiApiKey: Bool {
        !geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    public var geminiApiKeyHint: String? {
        let trimmed = geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return nil }
        return "••••" + trimmed.suffix(4)
    }
    public enum ConfigurationError: LocalizedError {
        case locked
        case storageFailure

        public var errorDescription: String? {
            switch self {
            case .locked:
                return "La configurazione dell'IA è riservata all'amministratore."
            case .storageFailure:
                return "Impossibile salvare la chiave nel portachiavi di sistema. La configurazione non è stata applicata."
            }
        }
    }
    public func setGeminiApiKey(_ key: String) throws {
        guard adminLock.isUnlocked else { throw ConfigurationError.locked }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard KeychainStore.save(trimmed, for: .geminiApiKey) else {
            throw ConfigurationError.storageFailure
        }
        geminiApiKey = trimmed
    }
    public var selectedFormat: DidacticFormat {
        didSet { SettingsStore.save(lastFormat: selectedFormat) }
    }
    public var engineOverride: AIEngine? = nil
    public var systemModelStatus: SystemModelAvailability.Status = SystemModelAvailability.status
    public var engineSelector: EngineSelector {
        EngineSelector(hasApiKey: hasGeminiApiKey, systemStatus: systemModelStatus)
    }
    public var activeEngine: AIEngine? {
        let selector = engineSelector
        if let engineOverride, selector.usableEngines.contains(engineOverride) { return engineOverride }
        return selector.recommended(for: selectedFormat)
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
    public var engineRationale: String? {
        if let licenseProblem = LicenseGate.explanation(licenseState) { return licenseProblem }
        if selectedFormat.isComposedLocally {
            return "Questo formato non usa l'IA: si compila dalle misure registrate nella scheda dell'alunno, "
                 + "con le diciture della normativa. Niente esce dal Mac."
        }
        if selectedFormat.localComposition == .fromAnyText, engineOverride == nil {
            switch selectedFormat {
            case .deskCheatSheet:
                return "Cerca formule, definizioni e dati nel testo, senza IA. Poi taglia: "
                     + "un formulario da banco vale se è corto."
            case .clearExplanation:
                return "Senza IA rende il testo leggibile e misura dov'è difficile, "
                     + "ma non riscrive le frasi: quello richiede di sapere quali parole "
                     + "l'alunno ha già. Con una API key le riscrive il modello."
            default:
                return "Estrae i termini dal testo senza IA, con la frase in cui compaiono. "
                     + "Le definizioni le scrivi tu; per farle scrivere all'IA, scegli un motore a mano."
            }
        }
        if selectedFormat.localComposition == .fromStructuredText {
            return "Incolla la verifica della classe con i quesiti numerati: l'app la ricostruisce senza IA — "
                 + "tempo maggiorato, strumenti concessi, spazio per scrivere e griglia. "
                 + "La scomposizione guidata la aggiungi tu."
        }
        guard let engine = activeEngine else { return engineSelector.blockingMessage }
        return engineSelector.rationale(for: selectedFormat, engine: engine)
    }
    public var canGenerate: Bool {
        guard LicenseGate.canGenerate(licenseState) else { return false }
        if activeEngine != nil { return true }
        switch selectedFormat.localComposition {
        case .always:
            return true
        case .fromStructuredText, .fromAnyText:
            return !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .none:
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

    // MARK: - Indice documentale (RAG)
    public private(set) var indexedDocuments: [IndexedDocument] = []
    public private(set) var isImportingDocuments: Bool = false
    public var indexedChunkCount: Int { indexedDocuments.reduce(0) { $0 + $1.chunkCount } }
    public var hasNoStudents: Bool { students.isEmpty }

    // MARK: - Servizi
    public let audioReader: AudioReaderService
    public let semanticSearch: SemanticSearchService
    public let docxExporter: DocxExportService
    public let dictation: SpeechDictationService
    // MARK: - Inizializzazione
    public init(
        modelContext: ModelContext,
        audioReader: AudioReaderService? = nil,
        semanticSearch: SemanticSearchService? = nil,
        docxExporter: DocxExportService? = nil
    ) {
        self.modelContext = modelContext
        self.audioReader = audioReader ?? AudioReaderService()
        self.semanticSearch = semanticSearch ?? SemanticSearchService()
        self.docxExporter = docxExporter ?? DocxExportService()
        self.dictation = SpeechDictationService()
        self.schoolInfo = PersistenceController.loadOrCreateSchoolInfo(in: modelContext)
        self.accessibilitySettings = SettingsStore.loadAccessibilitySettings()
        self.selectedFormat = SettingsStore.loadLastFormat()
        self.geminiApiKey = KeychainStore.read(.geminiApiKey) ?? ""

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

    // MARK: - Indice documentale (RAG)
    public func importDocuments(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isImportingDocuments = true
        errorMessage = nil
        statusMessage = nil
        let search = semanticSearch
        var importedTitles: [String] = []
        var totalChunks = 0
        var failures: [String] = []
        var singleDocumentText: String?
        for url in urls {
            do {
                let imported = try await Task.detached(priority: .userInitiated) {
                    try search.importDocument(url: url)
                }.value
                importedTitles.append(imported.title)
                totalChunks += imported.chunkCount
                if urls.count == 1 { singleDocumentText = imported.text }
            } catch {
                failures.append("\(url.lastPathComponent) — \(error.localizedDescription)")
            }
        }
        var filledEditor = false
        if let singleDocumentText,
           singleDocumentText.count <= Self.editorFillLimit,
           sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sourceText = singleDocumentText
            filledEditor = true
        }
        refreshIndexState()
        isImportingDocuments = false
        if !importedTitles.isEmpty {
            let names = importedTitles.joined(separator: ", ")
            if filledEditor {
                statusMessage = "«\(names)» è ora il testo di partenza nell'editor, e i suoi "
                    + "\(Plural.it(totalChunks, "frammento", "frammenti")) sono consultabili dall'IA. "
                    + "Modificalo pure prima di generare."
            } else {
                statusMessage = importedTitles.count == 1
                    ? "Indicizzato «\(names)»: \(Plural.it(totalChunks, "frammento", "frammenti")) consultabili dall'IA."
                    : "Indicizzati \(Plural.it(importedTitles.count, "documento", "documenti")) (\(names)): \(Plural.it(totalChunks, "frammento", "frammenti")) in tutto."
            }
        }
        if !failures.isEmpty {
            errorMessage = failures.count == 1
                ? "Non è stato possibile leggere \(failures[0])"
                : "Non è stato possibile leggere \(failures.count) file:\n• " + failures.joined(separator: "\n• ")
        }
    }
    public func indexEditorText() async {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Non c'è testo da indicizzare nell'editor."
            return
        }
        let search = semanticSearch
        let text = sourceText
        let count = await Task.detached(priority: .userInitiated) {
            search.indexRawText(text: text)
        }.value
        refreshIndexState()
        errorMessage = nil
        statusMessage = "Indicizzati \(Plural.it(count, "frammento", "frammenti")) del testo dell'editor."
    }

    public func removeIndexedDocument(_ document: IndexedDocument) {
        semanticSearch.removeDocument(title: document.title)
        refreshIndexState()
        errorMessage = nil
        statusMessage = "«\(document.title)» rimosso dall'indice."
    }

    public func clearSemanticIndex() {
        semanticSearch.clearIndex()
        refreshIndexState()
        errorMessage = nil
        statusMessage = "Indice svuotato."
    }

    private func refreshIndexState() {
        indexedDocuments = semanticSearch.indexedDocuments
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
        if selectedFormat.isComposedLocally {
            composeLocally(for: student)
            rememberWork()
            return
        }
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Inserisci il testo base della lezione o della verifica curricolare."
            return
        }
        guard !SourceTextCheck.looksLikeAnInstruction(sourceText) else {
            errorMessage = SourceTextCheck.instructionExplanation(for: sourceText)
            return
        }
        if selectedFormat.localComposition == .fromAnyText, engineOverride == nil {
            composeFromText(for: student)
            rememberWork()
            return
        }
        if selectedFormat.localComposition == .fromStructuredText {
            let exam = ExamParser.parse(sourceText)
            if !exam.isEmpty {
                composeEquipollente(exam, for: student)
                rememberWork()
            return
            }
            guard activeEngine != nil else {
                errorMessage = "Non ho riconosciuto quesiti numerati in questo testo, quindi non posso "
                    + "ricostruirlo da solo. Incolla la verifica della classe con i quesiti numerati "
                    + "(1., 2., 3.), oppure configura una API key per farla scrivere all'IA."
                return
            }
        }
        guard let engine = activeEngine else {
            errorMessage = engineSelector.blockingMessage
            return
        }
        await generate(with: engine, for: student)
    }

    private func generate(with engine: AIEngine, for student: StudentProfile) async {
        isGenerating = true
        generatedContent = ""
        errorMessage = nil
        statusMessage = nil

        let prompt = buildPrompt(for: student, engine: engine)
        let studentName = student.name

        do {
            let service = try engineSelector.makeService(engine, apiKey: geminiApiKey)
            let result = try await service.generateStreaming(prompt: prompt) { token in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let tail = self.generatedContent.suffix(StudentPseudonymizer.placeholder.count)
                    let head = self.generatedContent.dropLast(tail.count)
                    let rewritten = StudentPseudonymizer.restoreIdentity(
                        in: String(tail) + token,
                        name: studentName
                    )
                    self.generatedContent = String(head) + rewritten
                }
            }
            generatedContent = StudentPseudonymizer.restoreIdentity(in: result, name: studentName)
            rememberWork()
        } catch {
            errorMessage = failureMessage(for: error)
        }

        isGenerating = false
    }
    public func applySimplifiedText(_ text: String, rewritten: Int, gulpease: Int) {
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
        guard !nodes.isEmpty else { return }
        generatedContent = MindmapComposer.compose(nodes)
        selectedFormat = .conceptMap
        errorMessage = nil
        statusMessage = "Mappa pronta senza IA. Lo studente la trova navigabile nella sua scheda."
        rememberWork()
    }
    public func applyQuiz(_ questions: [QuizQuestion]) {
        guard !questions.isEmpty else { return }
        generatedContent = QuizComposer.compose(questions)
        selectedFormat = .interactiveQuiz
        rememberWork()
        errorMessage = nil
        statusMessage = "\(Plural.it(questions.count, "domanda pronta", "domande pronte")) senza IA. "
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
                : "\(Plural.it(terms.count, "termine trovato", "termini trovati")) senza IA. "
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
                : "\(Plural.it(entries.count, "voce trovata", "voci trovate")) senza IA. "
                  + "Il formulario vale se è corto: togli quello che l'alunno ha già acquisito."

        default:
            errorMessage = "Questo formato non ha ancora una composizione senza IA."
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
        statusMessage = "Ricostruita senza IA da \(quesiti). Aggiungi tu la scomposizione guidata "
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
            statusMessage = "Scheda compilata dalle misure registrate per \(student.name). Nessun dato è uscito dal Mac."
        default:
            errorMessage = "Questo formato non ha ancora una composizione senza IA."
        }
    }
    func failureMessage(for error: Error) -> String {
        guard let modelError = error as? SystemModelError,
              modelError == .contextTooLong,
              !generatedContent.isEmpty
        else { return error.localizedDescription }

        return """
        Il modello integrato nel Mac ha esaurito lo spazio mentre scriveva: \
        qui sotto c'è solo la parte iniziale, non consegnarla così com'è. \
        "\(selectedFormat.title)" è un formato lungo e non ci sta. \
        Con una API key di Google Gemini nelle impostazioni arriva in fondo.
        """
    }
    func buildPrompt(for student: StudentProfile, engine: AIEngine? = nil) -> String {
        let usesCloud = (engine ?? activeEngine) == .gemini
        let template = selectedFormat.systemPrompt(tablesSupported: usesCloud)
            .replacingOccurrences(of: "{INTEREST}", with: student.interest)
        let ragChunks = sourceText.count > 1500
            ? []
            : semanticSearch.searchRelevantContext(query: sourceText, topK: 2)
        let ragContext = ragChunks.isEmpty ? "" : """

        [CONTESTO DOCUMENTALE ESTRATTO DAI MATERIALI INDICIZZATI]:
        \(ragChunks.map(\.text).joined(separator: "\n---\n"))
        """

        return """
        \(template)
        \(StudentPseudonymizer.promptProfile(for: student))
        \(ragContext)
        TESTO / VERIFICA CURRICOLARE DA TRASFORMARE:
        \"\"\"
        \(sourceText)
        \"\"\"
        Genera adesso il materiale didattico completo e pronto all'uso.
        """
    }
}
