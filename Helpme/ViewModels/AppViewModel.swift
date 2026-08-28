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
        didSet { if selectedStudent !== oldValue { generatedContent = "" } }
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

    public var engineSelector: EngineSelector {
        EngineSelector(hasApiKey: hasGeminiApiKey)
    }

    /// Il motore che verrà effettivamente usato.
    public var activeEngine: AIEngine? {
        let selector = engineSelector
        if let engineOverride, selector.usableEngines.contains(engineOverride) { return engineOverride }
        return selector.recommended(for: selectedFormat)
    }

    /// Riga di spiegazione da mostrare accanto al pulsante di generazione.
    public var engineRationale: String? {
        guard let engine = activeEngine else { return engineSelector.blockingMessage }
        return engineSelector.rationale(for: selectedFormat, engine: engine)
    }

    public var canGenerate: Bool { activeEngine != nil }

    // MARK: - Editor

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

        for url in urls {
            do {
                let count = try await Task.detached(priority: .userInitiated) {
                    try search.indexDocument(url: url)
                }.value
                importedTitles.append(url.deletingPathExtension().lastPathComponent)
                totalChunks += count
            } catch {
                failures.append("\(url.lastPathComponent) — \(error.localizedDescription)")
            }
        }

        refreshIndexState()
        isImportingDocuments = false

        if !importedTitles.isEmpty {
            let names = importedTitles.joined(separator: ", ")
            statusMessage = importedTitles.count == 1
                ? "Indicizzato «\(names)»: \(Plural.it(totalChunks, "frammento", "frammenti")) consultabili dall'IA."
                : "Indicizzati \(Plural.it(importedTitles.count, "documento", "documenti")) (\(names)): \(Plural.it(totalChunks, "frammento", "frammenti")) in tutto."
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
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Inserisci il testo base della lezione o della verifica curricolare."
            return
        }
        guard let student = selectedStudent else {
            errorMessage = "Seleziona prima una scheda alunno."
            return
        }

        guard let engine = activeEngine else {
            errorMessage = engineSelector.blockingMessage
            return
        }

        isGenerating = true
        generatedContent = ""
        errorMessage = nil
        statusMessage = nil

        let prompt = buildPrompt(for: student)
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
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    /// Assembla il prompt. I dati dell'alunno passano dal pseudonimizzatore:
    /// nome e riferimenti diagnostici non lasciano il dispositivo.
    func buildPrompt(for student: StudentProfile) -> String {
        let template = selectedFormat.systemPromptTemplate
            .replacingOccurrences(of: "{INTEREST}", with: student.interest)

        let ragChunks = semanticSearch.searchRelevantContext(query: sourceText, topK: 2)
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
