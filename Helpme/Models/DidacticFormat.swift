import Foundation

public enum DidacticFormat: String, CaseIterable, Codable, Sendable {
    case equipollenteExam = "equipollente_exam"
    case deskCheatSheet = "desk_cheat_sheet"
    case pdpSummary = "pdp_summary"
    case conceptMap = "concept_map"
    case glossary = "glossary"
    case clearExplanation = "clear_explanation"
    case interactiveQuiz = "interactive_quiz"
    
    public var title: String {
        switch self {
        case .equipollenteExam: return "Verifica Equipollente (DSA/PEI)"
        case .deskCheatSheet: return "Formulario & Scheda da Banco"
        case .pdpSummary: return "Scheda Sintesi PDP"
        case .conceptMap: return "Mappa Concettuale"
        case .glossary: return "Glossario con Analogie"
        case .clearExplanation: return "Spiegazione Semplificata"
        case .interactiveQuiz: return "Quiz di Autoverifica"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .equipollenteExam: return "Tempo +30%, quesiti scomposti, griglia Consiglio di Classe"
        case .deskCheatSheet: return "Misure compensative L. 170/2010 a supporto visivo continuo"
        case .pdpSummary: return "Riepilogo strumenti compensativi e dispensativi personalizzati"
        case .conceptMap: return "Struttura ad albero logico-visiva per memorizzazione"
        case .glossary: return "Termini tecnici con spiegazione ed esempi vicini agli interessi"
        case .clearExplanation: return "Frasi brevi, lessico chiaro, formattazione anti-affaticamento"
        case .interactiveQuiz: return "Domande a scelta multipla con feedback immediato"
        }
    }
    

    public enum LocalComposition: Sendable {
        case always
        case fromStructuredText
        case fromAnyText
        case builtByTeacher
    }

    /// Come si produce il formato. Nessuno passa da un modello: sei formati si
    /// compongono dal testo o dalla scheda dell'alunno, e i due che non si
    /// possono dedurre da un testo li scrive il docente negli editor dedicati.
    public var localComposition: LocalComposition {
        switch self {
        case .pdpSummary:       return .always
        case .equipollenteExam: return .fromStructuredText
        case .glossary, .deskCheatSheet, .clearExplanation: return .fromAnyText
        case .conceptMap, .interactiveQuiz: return .builtByTeacher
        }
    }
    public var isComposedLocally: Bool { localComposition == .always }
}
