import Foundation

public enum AIEngine: String, CaseIterable, Codable, Sendable {
    case systemModel
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

@MainActor
public struct EngineSelector {

    public let systemStatus: SystemModelAvailability.Status
    public let hasApiKey: Bool

    public init(hasApiKey: Bool, systemStatus: SystemModelAvailability.Status = SystemModelAvailability.status) {
        self.hasApiKey = hasApiKey
        self.systemStatus = systemStatus
    }

    public var isSystemModelUsable: Bool { systemStatus == .available }

    public var usableEngines: [AIEngine] {
        var engines: [AIEngine] = []
        if isSystemModelUsable { engines.append(.systemModel) }
        if hasApiKey { engines.append(.gemini) }
        return engines
    }
    public func recommended(for format: DidacticFormat) -> AIEngine? {
        guard !usableEngines.isEmpty else { return nil }

        if format.needsCloudQuality, usableEngines.contains(.gemini) { return .gemini }
        if usableEngines.contains(.systemModel) { return .systemModel }
        return usableEngines.first
    }

    public func rationale(for format: DidacticFormat, engine: AIEngine) -> String {
        switch engine {
        case .systemModel:
       
            if format.needsCloudQuality {
                return "Attenzione: senza API key questo formato lo genera il modello del Mac, "
                     + "che tende a rispondere alle domande invece di lasciarle aperte e sbaglia i calcoli. "
                     + "Rileggi tutto prima di consegnare."
            }
            return usableEngines.contains(.gemini)
                ? "\(format.title): il modello del Mac basta, e i dati non escono da qui."
                : "Nessuna API key configurata: si usa il modello integrato nel Mac."
        case .gemini:
            return isSystemModelUsable
                ? "\(format.title) è un documento lungo e strutturato: qui Gemini fa un lavoro migliore."
                : "Il modello integrato non è disponibile su questo Mac: si usa Gemini."
        }
    }

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

    public var blockingMessage: String? {
        guard usableEngines.isEmpty else { return nil }
        if let explanation = systemStatus.explanation {
            return "\(explanation) In alternativa, inserisci una API key di Google Gemini nelle impostazioni."
        }
        return "Nessun motore disponibile: attiva Apple Intelligence oppure inserisci una API key di Google Gemini."
    }
}
