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
    
    /// Come si produce questo formato senza modello linguistico.
    public enum LocalComposition: Sendable {
        /// Basta la scheda dell'alunno: si compone sempre.
        case always
        /// Serve un testo con una struttura riconoscibile — una verifica con
        /// quesiti numerati. Se il testo non ce l'ha, l'app lo dice.
        case fromStructuredText
        /// Basta un testo qualsiasi, senza struttura particolare.
        case fromAnyText
        /// Per ora richiede un modello.
        case none
    }

    public var localComposition: LocalComposition {
        switch self {
        case .pdpSummary:       return .always
        case .equipollenteExam: return .fromStructuredText
        case .glossary, .deskCheatSheet: return .fromAnyText
        default:                return .none
        }
    }

    /// Vero per i formati che l'app produce da sé, senza nessun modello.
    ///
    /// Non è un ripiego per chi non ha una chiave: è la forma giusta per
    /// questo documento. La Scheda PDP riepiloga misure deliberate dal
    /// Consiglio di Classe, e il suo valore sta nel riportare *esattamente*
    /// le parole della normativa — cosa che un modello, parafrasandole un po'
    /// diverse a ogni generazione, peggiorava senza aggiungere niente.
    public var isComposedLocally: Bool { localComposition == .always }

    /// Vero per i formati che il modello integrato non regge.
    ///
    /// Non è una stima: misurato il 28 agosto 2026 sul modello on-device di
    /// Apple (~3B) con una verifica di meccanica agraria reale. In 19
    /// secondi ha prodotto un documento ben impaginato che però
    /// **rispondeva alle domande invece di lasciarle aperte** — ignorando
    /// una regola scritta in maiuscolo come prima istruzione — sbagliava il
    /// calcolo del consumo di un fattore dieci, e definiva il rapporto di
    /// compressione come rapporto tra pressioni anziché tra volumi.
    ///
    /// Il quiz sta qui per la stessa ragione: chiede quattro distrattori
    /// plausibili e una spiegazione per ciascuno, che è lo stesso genere di
    /// compito a vincoli multipli.
    public var needsCloudQuality: Bool {
        switch self {
        case .equipollenteExam, .interactiveQuiz:
            return true
        case .clearExplanation, .glossary, .conceptMap, .deskCheatSheet, .pdpSummary:
            return false
        }
    }

    /// Il prompt di sistema, adattato a cosa il motore sa fare.
    ///
    /// `tablesSupported` esiste per un difetto misurato il 29 agosto 2026: il
    /// modello integrato nel Mac, arrivato a una tabella markdown, comincia a
    /// incolonnare le celle con spazi e non smette più, finché esaurisce la
    /// finestra di contesto e la generazione fallisce. La verifica
    /// equipollente falliva così in 54 secondi e il formulario in 57 —
    /// **gli unici due formati che chiedevano una tabella**. Chiedendo gli
    /// stessi contenuti come elenco riescono entrambi in 9 secondi, con
    /// l'uscita pulita.
    ///
    /// Gemini le tabelle le fa bene, e nel documento Word diventano tabelle
    /// vere con l'intestazione ripetuta: quindi si rinuncia solo dove serve.
    public func systemPrompt(tablesSupported: Bool) -> String {
        let template = systemPromptTemplate
        guard !tablesSupported else { return template }

        return template
            .replacingOccurrences(
                of: "come TABELLA markdown con le barre verticali, colonne: Indicatore | Descrittore | Punti.",
                with: "come elenco puntato: una riga per indicatore, nella forma \"- Indicatore — descrittore — punti\".")
            .replacingOccurrences(
                of: "Formatta con tabelle a 2 colonne, schemi a punti elenco sintetici e formule chiare.",
                with: "Formatta con elenchi puntati sintetici e formule chiare. Non usare tabelle.")
    }

    public var systemPromptTemplate: String {
        switch self {
        case .equipollenteExam:
            return """
            Sei un assistente specializzato per Docenti di Sostegno delle Scuole Superiori (D.I. 182/2020, L. 104/1992, L. 170/2010).
            Trasforma il testo o la verifica fornita in una VERIFICA EQUIPOLLENTE.

            REGOLA ASSOLUTA — NON RISPONDERE ALLE DOMANDE.
            Stai preparando il foglio che lo studente dovrà svolgere, non la
            sua correzione. Non risolvere i problemi, non eseguire i calcoli,
            non definire i termini: lascia lo spazio dove lo studente scriverà.
            Un solo esempio svolto è ammesso, ma solo se etichettato
            "Esempio guidato" e diverso dai quesiti assegnati.

            Poi:
            1. Mantieni rigorosamente gli obiettivi curricolari della classe (percorso Minimi/Equipollente).
            2. Applica le misure compensative: tempo aggiuntivo (+30%), scomposizione di problemi complessi in micro-step guidati.
            3. Riduci il carico di lettura/scrittura manuale (domande a scelta multipla, cloze test, collegamenti logici).
            4. Inserisci sempre la Griglia di Valutazione per il Consiglio di Classe, come TABELLA markdown con le barre verticali, colonne: Indicatore | Descrittore | Punti.
            5. Inserisci analogie o esempi legati all'interesse dell'alunno: {INTEREST}.
            6. Non introdurre dati tecnici, formule o valori numerici che non
               siano già nel testo di partenza: se un dato manca, lascia uno
               spazio da compilare invece di inventarlo.
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
