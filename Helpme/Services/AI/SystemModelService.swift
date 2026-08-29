import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Inferenza con il modello integrato in macOS / iPadOS (Apple Intelligence).
///
/// Non richiede API key né download: il modello è già nel sistema e i dati
/// non lasciano il dispositivo. In cambio è un modello compatto, con una
/// finestra di contesto stretta: regge bene le riscritture e le estrazioni,
/// meno i documenti lunghi a vincoli multipli.
@available(macOS 26.0, iOS 26.0, *)
public final class SystemModelService: LLMInferenceService, @unchecked Sendable {

    private let instructions: String?
    private let temperature: Double

    public init(instructions: String? = nil, temperature: Double = 0.3) {
        self.instructions = instructions
        self.temperature = temperature
    }

    public func generateStreaming(prompt: String, onToken: @escaping @Sendable (String) -> Void) async throws -> String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled: throw SystemModelError.appleIntelligenceOff
            case .deviceNotEligible:           throw SystemModelError.deviceNotEligible
            case .modelNotReady:               throw SystemModelError.modelDownloading
            @unknown default:                  throw SystemModelError.frameworkMissing
            }
        }

        let session: LanguageModelSession
        if let instructions {
            session = LanguageModelSession(instructions: instructions)
        } else {
            session = LanguageModelSession()
        }

        let options = GenerationOptions(temperature: temperature)

        do {
            let stream = session.streamResponse(to: prompt, options: options)
            var emitted = ""

            for try await snapshot in stream {
                // Gli snapshot sono cumulativi: il protocollo vuole i delta.
                let text = snapshot.content
                guard text.count > emitted.count else { continue }
                let delta = String(text.dropFirst(emitted.count))
                emitted = text
                onToken(delta)
            }

            // Questo modello, quando incontra qualcosa che non sa chiudere,
            // riempie la coda di spazi: una volta misurati quindicimila
            // caratteri di spazi dopo ottocento di contenuto. Nel documento
            // finirebbero come pagine bianche.
            let cleaned = emitted.replacingOccurrences(
                of: "[ \t]+$", with: "", options: [.regularExpression]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleaned.isEmpty else { throw SystemModelError.emptyResponse }
            return cleaned

        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize: throw SystemModelError.contextTooLong
            case .guardrailViolation:        throw SystemModelError.refusedByGuardrail
            default:                         throw SystemModelError.generationFailed(error.localizedDescription)
            }
        }
        #else
        throw SystemModelError.frameworkMissing
        #endif
    }
}

// MARK: - Errori

/// Errori del modello integrato, espressi senza portare i tipi di
/// FoundationModels fuori da questo file: i case con valori associati non
/// possono essere marcati come disponibili solo su macOS 26.
public enum SystemModelError: LocalizedError, Equatable {
    case frameworkMissing
    case emptyResponse
    case appleIntelligenceOff
    case deviceNotEligible
    case modelDownloading
    case contextTooLong
    case refusedByGuardrail
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .frameworkMissing:
            return "Il modello integrato non è disponibile su questa versione del sistema. Usa Google Gemini."
        case .emptyResponse:
            return "Il modello integrato non ha prodotto testo. Prova con un brano più corto."
        case .appleIntelligenceOff:
            return "Apple Intelligence non è attiva. Attivala da Impostazioni di Sistema › Apple Intelligence e Siri, oppure usa Google Gemini."
        case .deviceNotEligible:
            return "Questo dispositivo non supporta il modello integrato. Usa Google Gemini."
        case .modelDownloading:
            return "Il modello integrato si sta ancora scaricando. Riprova tra qualche minuto."
        case .contextTooLong:
            // La finestra del modello integrato contiene il testo di partenza
            // e il documento che sta scrivendo, insieme. Su un formato lungo
            // si esaurisce mentre genera, anche se il testo di partenza era di
            // due righe: dire solo "accorcia il testo" manda il docente a
            // tagliare la lezione senza che serva a niente.
            return "Il modello integrato ha esaurito lo spazio disponibile: la sua memoria di lavoro deve contenere insieme il testo di partenza e il documento da produrre. Se ne è già comparso un pezzo, è solo l'inizio e non va consegnato. Accorcia il testo di partenza, oppure usa Google Gemini che regge documenti molto più lunghi."
        case .refusedByGuardrail:
            return "Il modello integrato ha rifiutato di elaborare questo contenuto. Se il testo è didatticamente legittimo, usa Google Gemini."
        case .generationFailed(let detail):
            return "Il modello integrato non è riuscito a generare la risposta: \(detail)"
        }
    }
}

// MARK: - Disponibilità

/// Interroga il sistema senza costringere il resto dell'app a conoscere
/// FoundationModels o a preoccuparsi della versione di macOS.
public nonisolated enum SystemModelAvailability {

    public enum Status: Equatable {
        case available
        case appleIntelligenceOff
        case deviceNotEligible
        case downloading
        case systemTooOld
        case unknown

        /// Messaggio da mostrare accanto alla scelta del motore.
        public var explanation: String? {
            switch self {
            case .available:
                return nil
            case .appleIntelligenceOff:
                return "Attiva Apple Intelligence nelle Impostazioni di Sistema per usare il modello integrato, senza API key."
            case .deviceNotEligible:
                return "Questo Mac non supporta il modello integrato."
            case .downloading:
                return "Il modello integrato si sta scaricando."
            case .systemTooOld:
                return "Il modello integrato richiede macOS 26 o successivo."
            case .unknown:
                return "Il modello integrato non è disponibile."
            }
        }
    }

    public static var status: Status {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, iOS 26.0, *) else { return .systemTooOld }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
            case .deviceNotEligible:           return .deviceNotEligible
            case .modelNotReady:               return .downloading
            @unknown default:                  return .unknown
            }
        }
        #else
        return .systemTooOld
        #endif
    }

    public static var isAvailable: Bool { status == .available }
}
