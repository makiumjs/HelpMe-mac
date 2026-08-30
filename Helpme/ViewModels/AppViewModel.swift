import Foundation
import SwiftUI
import SwiftData

/// Stato condiviso dell'app.
///
/// È isolato su `@MainActor`: tutte le proprietà osservate da SwiftUI vengono
/// scritte sul main thread, anche durante lo streaming della risposta dell'IA.
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
            // Il lavoro dell'alunno che si lascia non si butta: si mette via
            // sulla sua scheda, e si riprende quello dell'alunno che si apre.
            //
            // Si salva **solo** se un alunno precedente c'era davvero. Con
            // @Observable questo osservatore scatta anche dentro
            // l'inizializzatore, dove oldValue e' nil: ricadendo in quel caso
            // sull'alunno appena selezionato gli si sovrascriveva il
            // materiale salvato con lo stato vuoto in memoria, cioe' si
            // cancellava il lavoro a ogni avvio.
            if let previous = oldValue { store(into: previous) }
            restoreWork(of: selectedStudent)
        }
    }

    /// Mette via testo di partenza e materiale sulla scheda dell'alunno.
    ///
    /// Va chiamata quando l'app perde il primo piano e dopo ogni
    /// generazione: prima il lavoro viveva solo in memoria e ogni chiusura
    /// dell'app lo cancellava, senza che niente lo avvertisse.
    public func rememberWork() {
        guard let student = selectedStudent else { return }
        store(into: student)
    }

    private func store(into student: StudentProfile) {
        guard student.lastSourceText != sourceText
                || student.lastGeneratedContent != generatedContent else { return }

        student.lastSourceText = sourceText
        student.lastGeneratedContent = generatedContent
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

    /// Il blocco che protegge la configurazione dell'IA: la chiave la
    /// inserisce chi installa l'app, non il docente.
    public let adminLock = AdminLock()

    /// La chiave in chiaro non è scrivibile dall'esterno: passa da
    /// `setGeminiApiKey(_:)`, che pretende il blocco aperto. Così nessuna
    /// vista può cambiarla per sbaglio con un binding.
    public private(set) var geminiApiKey: String

    /// Vero se una chiave è configurata su questa macchina.
    public var hasGeminiApiKey: Bool {
        !geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Le ultime quattro cifre, per riconoscere quale chiave c'è sopra una
    /// macchina senza mostrarla per intero.
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

    /// Scrive la chiave nel portachiavi. Richiede il blocco aperto.
    ///
    /// Il valore in memoria si aggiorna **solo se** il portachiavi ha
    /// accettato la scrittura: altrimenti l'app crederebbe di avere una
    /// chiave che al riavvio successivo non c'è più, e la generazione
    /// fallirebbe senza che nulla punti al salvataggio andato male.
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

    /// Motore scelto a mano dal docente. Se resta `nil` decide l'app,
    /// in base a cosa è disponibile e al formato richiesto.
    public var engineOverride: AIEngine? = nil

    /// Disponibilità del modello integrato. Si legge dal sistema all'avvio;
    /// resta scrivibile perché il caso "nessun motore" — Mac senza Apple
    /// Intelligence e senza chiave — è un ramo che l'app deve gestire bene e
    /// che altrimenti si potrebbe provare solo su un Mac vecchio.
    public var systemModelStatus: SystemModelAvailability.Status = SystemModelAvailability.status

    public var engineSelector: EngineSelector {
        EngineSelector(hasApiKey: hasGeminiApiKey, systemStatus: systemModelStatus)
    }

    /// Il motore che verrà effettivamente usato.
    public var activeEngine: AIEngine? {
        let selector = engineSelector
        if let engineOverride, selector.usableEngines.contains(engineOverride) { return engineOverride }
        return selector.recommended(for: selectedFormat)
    }

    // MARK: - Licenza

    public internal(set) var licenseState: LicenseState = LicenseVerifier.verify(
        token: SettingsStore.loadLicenseToken() ?? ""
    )

    /// Rilegge la licenza dal disco e la rivaluta rispetto a adesso.
    ///
    /// Serve perché lo stato è calcolato all'avvio: un'app lasciata aperta
    /// sulla cattedra oltre la mezzanotte dell'ultimo giorno continuerebbe a
    /// credersi valida. Va chiamata quando l'app torna in primo piano.
    public func refreshLicenseState() {
        licenseState = LicenseVerifier.verify(token: SettingsStore.loadLicenseToken() ?? "")
    }

    /// Registra un codice licenza. Restituisce lo stato risultante, così chi
    /// lo incolla vede subito se è andato a buon fine o cos'è che non va.
    @discardableResult
    public func activate(licenseToken: String) -> LicenseState {
        let state = LicenseVerifier.verify(token: licenseToken)
        // Un codice che non regge la verifica non si salva: meglio restare
        // com'eravamo che sostituire una licenza buona con una storta.
        if case .valid = state { SettingsStore.save(licenseToken: licenseToken) }
        licenseState = state
        return state
    }

    /// Riga di spiegazione da mostrare accanto al pulsante di generazione.
    ///
    /// La licenza viene prima: se blocca lei, dire al docente quale motore
    /// useremmo è un'informazione che non gli serve a niente.
    public var engineRationale: String? {
        if let licenseProblem = LicenseGate.explanation(licenseState) { return licenseProblem }
        if selectedFormat.isComposedLocally {
            return "Questo formato non usa l'IA: si compila dalle misure registrate nella scheda dell'alunno, "
                 + "con le diciture della normativa. Niente esce dal Mac."
        }
        if selectedFormat.localComposition == .fromAnyText, engineOverride == nil {
            return "Estrae i termini dal testo senza IA, con la frase in cui compaiono. "
                 + "Le definizioni le scrivi tu; per farle scrivere all'IA, scegli un motore a mano."
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
            // Non si analizza il testo qui: verrebbe rifatto a ogni battuta.
            // Se poi la struttura non c'è, la generazione lo dice.
            return !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .none:
            return false
        }
    }

    // MARK: - Editor

    /// Oltre questa soglia il documento importato non viene riversato
    /// nell'editor: un manuale intero lo renderebbe inutilizzabile, e chi
    /// importa qualcosa di quella mole lo sta indicizzando per la
    /// consultazione, non per adattarlo tutto. Sono all'incirca venticinque
    /// pagine.
    static let editorFillLimit = 50_000

    public var sourceText: String = ""
    public var generatedContent: String = ""
    public var isGenerating: Bool = false
    public var errorMessage: String? = nil
    public var statusMessage: String? = nil

    // MARK: - Indice documentale (RAG)

    /// Copia osservabile dello stato dell'indice: `SemanticSearchService` non
    /// è `@Observable`, quindi le viste guardano questa.
    public private(set) var indexedDocuments: [IndexedDocument] = []
    public private(set) var isImportingDocuments: Bool = false

    public var indexedChunkCount: Int { indexedDocuments.reduce(0) { $0 + $1.chunkCount } }

    /// Vero finché non esiste nessuna scheda alunno: la finestra mostra
    /// la schermata d'ingresso invece dell'area di lavoro.
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
        // I servizi si costruiscono qui e non come valori di default dei
        // parametri: quelli verrebbero valutati fuori dal main actor.
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
        // Le property observer non scattano dentro l'inizializzatore.
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

    /// Scrive su disco le modifiche fatte a una scheda gia' esistente.
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

        // Le voci GLO dell'alunno vengono rimosse insieme alla scheda.
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

    /// Indicizza i file scelti dal docente nel selettore di sistema.
    ///
    /// L'estrazione gira fuori dal main actor: aprire un PDF di duecento
    /// pagine sul thread della UI congelerebbe la finestra.
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

        // Chi importa *un* documento quasi sempre vuole adattare quello.
        // Prima il testo spariva nell'indice e l'editor restava vuoto, cosi'
        // il docente si trovava un pulsante "Genera" che partiva dal nulla e
        // pescava dall'indice quello che capitava. Non si sovrascrive mai
        // quello che il docente ha gia' scritto.
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

        // Un file scartato viene detto, non ingoiato: il docente deve sapere
        // che quel materiale non è finito nell'indice.
        if !failures.isEmpty {
            errorMessage = failures.count == 1
                ? "Non è stato possibile leggere \(failures[0])"
                : "Non è stato possibile leggere \(failures.count) file:\n• " + failures.joined(separator: "\n• ")
        }
    }

    /// Indicizza il testo incollato nell'editor.
    /// Indicizza il testo incollato nell'editor.
    ///
    /// La vettorizzazione gira fuori dal main actor come per i documenti
    /// importati: calcolare un `NLEmbedding` per ogni frammento di una
    /// lezione lunga bloccherebbe la finestra per secondi.
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

    /// Testo dell'editor com'era prima di iniziare a dettare.
    ///
    /// Il riconoscitore restituisce ogni volta l'intera frase riconosciuta
    /// fin lì, non il pezzo nuovo: si ricompone sempre da questa base,
    /// altrimenti le parole si accumulerebbero in duplicato.
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

    /// Riscrive l'editor con la trascrizione corrente.
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

        // I formati che si compongono da soli non chiedono niente a nessun
        // modello, e nemmeno un testo di partenza: quello che serve è già
        // nella scheda dell'alunno.
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

        // Il glossario si estrae dal testo senza modello. Se però il docente
        // ha scelto un motore a mano, vuol dire che vuole anche le
        // definizioni scritte: gliele si lascia chiedere.
        if selectedFormat.localComposition == .fromAnyText, engineOverride == nil {
            composeGlossary(for: student)
            rememberWork()
            return
        }

        // Se il testo è davvero una verifica, la equipollente si ricostruisce
        // senza modello: i contenuti sono già quelli giusti, li ha scelti il
        // docente curricolare, e l'equipollenza sta nel mantenerli.
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
                    // Si sostituisce il segnaposto solo nella coda del testo,
                    // non nell'intero accumulato: rifare la scansione completa
                    // a ogni token costa quadraticamente sul main actor, e su
                    // una verifica lunga si vede. La finestra tiene conto di un
                    // segnaposto spezzato a metà tra due token.
                    let tail = self.generatedContent.suffix(StudentPseudonymizer.placeholder.count)
                    let head = self.generatedContent.dropLast(tail.count)
                    let rewritten = StudentPseudonymizer.restoreIdentity(
                        in: String(tail) + token,
                        name: studentName
                    )
                    self.generatedContent = String(head) + rewritten
                }
            }
            // Il testo definitivo sostituisce quello accumulato in streaming.
            generatedContent = StudentPseudonymizer.restoreIdentity(in: result, name: studentName)
            rememberWork()
        } catch {
            errorMessage = failureMessage(for: error)
        }

        isGenerating = false
    }

    /// Mette nel materiale la mappa costruita dal docente.
    public func applyMindmap(_ nodes: [MindmapNode]) {
        guard !nodes.isEmpty else { return }
        generatedContent = MindmapComposer.compose(nodes)
        selectedFormat = .conceptMap
        errorMessage = nil
        statusMessage = "Mappa pronta senza IA. Lo studente la trova navigabile nella sua scheda."
        rememberWork()
    }

    /// Mette nel materiale il quiz scritto a mano dal docente.
    public func applyQuiz(_ questions: [QuizQuestion]) {
        guard !questions.isEmpty else { return }
        generatedContent = QuizComposer.compose(questions)
        selectedFormat = .interactiveQuiz
        rememberWork()
        errorMessage = nil
        statusMessage = "\(Plural.it(questions.count, "domanda pronta", "domande pronte")) senza IA. "
            + "Lo studente le trova nella sua scheda, cliccabili."
    }

    private func composeGlossary(for student: StudentProfile) {
        errorMessage = nil
        let terms = GlossaryExtractor.extract(from: sourceText)
        generatedContent = GlossaryComposer.compose(terms: terms, interest: student.interest)

        statusMessage = terms.isEmpty
            ? nil
            : "\(Plural.it(terms.count, "termine trovato", "termini trovati")) senza IA. "
              + "Togli quelli che non servono e scrivi le definizioni."
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

    /// Compone il materiale senza modello linguistico.
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

    /// Traduce l'errore in una frase su cui il docente possa agire davvero.
    ///
    /// Il caso che conta è il contesto esaurito a documento già cominciato:
    /// lì sappiamo che a sforare non è stato il testo di partenza ma la
    /// lunghezza di quello che il modello stava scrivendo, e possiamo dirlo
    /// invece di far accorciare una lezione che non c'entra.
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

    /// Assembla il prompt. I dati dell'alunno passano dal pseudonimizzatore:
    /// nome e riferimenti diagnostici non lasciano il dispositivo.
    func buildPrompt(for student: StudentProfile, engine: AIEngine? = nil) -> String {
        // Il modello integrato non regge le tabelle markdown: gli si chiede
        // la stessa cosa in forma di elenco. Vedi DidacticFormat.systemPrompt.
        let usesCloud = (engine ?? activeEngine) == .gemini
        let template = selectedFormat.systemPrompt(tablesSupported: usesCloud)
            .replacingOccurrences(of: "{INTEREST}", with: student.interest)

        // Quando il testo di partenza e' gia' sostanzioso, i frammenti
        // ripescati vengono quasi sempre dallo stesso documento: si
        // spedirebbe due volte la stessa cosa, proprio dove lo spazio manca.
        // Il recupero documentale serve a integrare un testo breve, non a
        // ripetere un testo lungo.
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
