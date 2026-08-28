import Foundation

/// I motori di inferenza tra cui l'app può scegliere.
public enum AIEngine: String, CaseIterable, Codable, Sendable {
    /// Modello integrato nel sistema: nessuna chiave, nessun dato fuori dal dispositivo.
    case systemModel
    /// Google Gemini: più capace sui documenti lunghi, richiede una API key.
    case gemini

    public var displayName: String {
        switch self {
        case .systemModel: return "Modello integrato nel Mac"
        case .gemini:      return "Google Gemini"
        }
    }

    public var subtitle: String {
        switch self {
        case .systemModel: return "Nessuna chiave, nessun dato inviato fuori"
        case .gemini:      return "Più capace sui testi lunghi, richiede una API key"
        }
    }

    public var iconName: String {
        switch self {
        case .systemModel: return "cpu"
        case .gemini:      return "cloud"
        }
    }
}

/// Decide quale motore usare e sa spiegare perché.
///
/// L'app deve funzionare su Mac molto diversi: dove il modello integrato c'è
/// lo usa senza chiedere niente a nessuno, altrove ricade su Gemini. Il docente
/// può sempre forzare la scelta, ma non è costretto a farla.
@MainActor
public struct EngineSelector {

    public let systemStatus: SystemModelAvailability.Status
    public let hasApiKey: Bool

    public init(hasApiKey: Bool, systemStatus: SystemModelAvailability.Status = SystemModelAvailability.status) {
        self.hasApiKey = hasApiKey
        self.systemStatus = systemStatus
    }

    public var isSystemModelUsable: Bool { systemStatus == .available }

    /// I motori realmente utilizzabili in questo momento.
    public var usableEngines: [AIEngine] {
        var engines: [AIEngine] = []
        if isSystemModelUsable { engines.append(.systemModel) }
        if hasApiKey { engines.append(.gemini) }
        return engines
    }

    /// Il motore consigliato per un certo formato didattico.
    ///
    /// I formati che riscrivono o estraggono da un testo dato stanno bene al
    /// modello integrato. La verifica equipollente completa — obiettivi
    /// curricolari da mantenere, misure compensative, quesiti scomposti e
    /// griglia di valutazione, tutto insieme e in un documento lungo — chiede
    /// di più: lì conviene il cloud, quando c'è.
    public func recommended(for format: DidacticFormat) -> AIEngine? {
        guard !usableEngines.isEmpty else { return nil }

        let wantsCloud: Bool
        switch format {
        case .equipollenteExam, .interactiveQuiz:
            wantsCloud = true
        case .clearExplanation, .glossary, .conceptMap, .deskCheatSheet, .pdpSummary:
            wantsCloud = false
        }

        if wantsCloud, usableEngines.contains(.gemini) { return .gemini }
        if usableEngines.contains(.systemModel) { return .systemModel }
        return usableEngines.first
    }

    /// Perché è stato scelto quel motore, in una riga da mostrare accanto al pulsante.
    public func rationale(for format: DidacticFormat, engine: AIEngine) -> String {
        switch engine {
        case .systemModel:
            return usableEngines.contains(.gemini)
                ? "\(format.title): il modello del Mac basta, e i dati non escono da qui."
                : "Nessuna API key configurata: si usa il modello integrato nel Mac."
        case .gemini:
            return isSystemModelUsable
                ? "\(format.title) è un documento lungo e strutturato: qui Gemini fa un lavoro migliore."
                : "Il modello integrato non è disponibile su questo Mac: si usa Gemini."
        }
    }

    /// Costruisce il servizio corrispondente.
    public func makeService(_ engine: AIEngine, apiKey: String) throws -> LLMInferenceService {
        switch engine {
        case .systemModel:
            guard #available(macOS 26.0, iOS 26.0, *), isSystemModelUsable else {
                throw SystemModelError.frameworkMissing
            }
            return SystemModelService()
        case .gemini:
            return GeminiService(apiKey: apiKey)
        }
    }

    /// Messaggio per quando non si può generare affatto.
    public var blockingMessage: String? {
        guard usableEngines.isEmpty else { return nil }
        if let explanation = systemStatus.explanation {
            return "\(explanation) In alternativa, inserisci una API key di Google Gemini nelle impostazioni."
        }
        return "Nessun motore disponibile: attiva Apple Intelligence oppure inserisci una API key di Google Gemini."
    }
}
