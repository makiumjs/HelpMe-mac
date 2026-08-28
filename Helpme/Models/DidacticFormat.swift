import Foundation

public enum DidacticFormat: String, CaseIterable, Codable, Sendable {
    case equipollenteExam = "equipollente_exam" // Verifica Equipollente (+30% tempo, quesiti guidati, griglia)
    case deskCheatSheet = "desk_cheat_sheet"   // Formulario & Scheda da Banco (L. 170/2010)
    case pdpSummary = "pdp_summary"            // Scheda Sintesi PDP / Misure
    case conceptMap = "concept_map"            // Mappa Concettuale Gerarchica
    case glossary = "glossary"                 // Glossario Termini con Analogie
    case clearExplanation = "clear_explanation"// Spiegazione Semplificata ad Alta Leggibilità
    case interactiveQuiz = "interactive_quiz"  // Quiz di Autoverifica Strutturato
    
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
    
    public var systemPromptTemplate: String {
        switch self {
        case .equipollenteExam:
            return """
            Sei un assistente specializzato per Docenti di Sostegno delle Scuole Superiori (D.I. 182/2020, L. 104/1992, L. 170/2010).
            Trasforma il testo o la verifica fornita in una VERIFICA EQUIPOLLENTE:
            1. Mantieni rigorosamente gli obiettivi curricolari della classe (percorso Minimi/Equipollente).
            2. Applica le misure compensative: tempo aggiuntivo (+30%), scomposizione di problemi complessi in micro-step guidati.
            3. Riduci il carico di lettura/scrittura manuale (domande a scelta multipla, cloze test, collegamenti logici).
            4. Inserisci sempre la Griglia di Valutazione per il Consiglio di Classe con indicatori descrittivi.
            5. Inserisci analogie o esempi legati all'interesse dell'alunno: {INTEREST}.
            """
        case .deskCheatSheet:
            return """
            Sei un esperto di didattica inclusiva per studenti con DSA e ADHD (L. 170/2010).
            Genera un FORMULARIO & SCHEDA DA BANCO da utilizzare durante verifiche e lezioni:
            1. Formatta con tabelle a 2 colonne, schemi a punti elenco sintetici e formule chiare.
            2. Evidenzia parole chiave in grassetto.
            3. Includi esempi applicativi concreti ed essenziali.
            """
        case .pdpSummary:
            return """
            Genera una SCHEDA SINTETICA PDP/PEI per i docenti del Consiglio di Classe:
            1. Strumenti compensativi attivi.
            2. Misure dispensative concordate.
            3. Strategie inclusive per le verifiche scritte e orali.
            """
        case .conceptMap:
            return """
            Genera una MAPPA CONCETTUALE gerarchica strutturata.

            FORMATO OBBLIGATORIO — l'app trasforma questo testo in una mappa
            navigabile, quindi rispetta esattamente la struttura:
            - Usa solo il trattino "-" come segno di elenco.
            - Ogni livello di profondità rientra di DUE spazi in più.
            - Massimo tre livelli.
            - Dove serve un dettaglio o un esempio, mettilo sulla stessa riga
              dopo " :: " (due punti doppi tra spazi).

            Esempio della forma attesa:
            - Tema principale
              - Concetto chiave :: spiegazione breve del concetto
                - Dettaglio o esempio pratico
              - Secondo concetto chiave
            """
        case .glossary:
            return """
            Estrai e spiega i TERMINI CHIAVE del testo:
            Per ogni termine fornisci:
            - Definizione chiara e semplice.
            - Analogia o metafora pratica collegata al tema: {INTEREST}.
            """
        case .clearExplanation:
            return """
            Riscrivi il testo seguente secondo le linee guida Easy-to-Read (alta leggibilità per DSA):
            - Frasi brevi (max 15-20 parole per frase).
            - Un solo concetto per riga.
            - Lessico comune o spiegazione immediata dei termini tecnici.
            - Spaziatura ariosa ed elenchi strutturati.
            """
        case .interactiveQuiz:
            return """
            Genera un QUIZ di 5 domande a risposta multipla (4 opzioni ciascuna):
            - 1 risposta corretta, 3 distrattori plausibili.
            - Spiegazione formativa immediata per ciascuna opzione, anche per
              quelle sbagliate: deve spiegare l'errore, non solo negarlo.

            FORMATO OBBLIGATORIO — l'app rende queste domande cliccabili,
            quindi rispetta esattamente questa struttura per ognuna:

            ### Domanda 1
            Testo della domanda?
            - [ ] Opzione sbagliata :: perché non è questa
            - [x] Opzione corretta :: perché è questa
            - [ ] Opzione sbagliata :: perché non è questa
            - [ ] Opzione sbagliata :: perché non è questa

            Usa "[x]" per la sola risposta giusta e "[ ]" per le altre tre.
            Non scrivere altrove quale sia la risposta corretta: rovinerebbe
            l'autoverifica dello studente.
            """
        }
    }
}
