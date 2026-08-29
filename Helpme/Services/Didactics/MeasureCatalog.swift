import Foundation

/// Una misura del Piano Didattico Personalizzato, con la sua fonte.
/// A quale voce del PDP appartiene una misura. Non e' una preferenza del
/// docente: e' come la classifica la normativa, e su un documento che cita
/// le norme dev'essere quella.
public nonisolated enum MeasureCategory: String, Sendable {
    case compensative
    case dispensative
    case assessment
}

public nonisolated struct DidacticMeasure: Identifiable, Hashable, Sendable {
    /// Stabile: è quello che finisce salvato nella scheda dell'alunno.
    public let id: String
    /// La dicitura come va scritta nel documento. Non si parafrasa.
    public let text: String
    /// La norma da cui viene, per chi legge il documento in Consiglio.
    public let reference: String
    public let category: MeasureCategory

    public init(id: String, text: String, reference: String, category: MeasureCategory) {
        self.id = id
        self.text = text
        self.reference = reference
        self.category = category
    }
}

/// Le misure previste dalla normativa, come catalogo scelto a mano.
///
/// Questa parte non passa da un modello linguistico, e non è una rinuncia: è
/// la scelta giusta. La dicitura di una misura compensativa è testo normativo
/// che il Consiglio di Classe delibera e che finisce in un fascicolo. Farla
/// riscrivere ogni volta a un modello — che la parafraserebbe in modo un po'
/// diverso a ogni generazione — introdurrebbe variabilità dove serve
/// esattamente il contrario, e nessun vantaggio.
///
/// Le diciture seguono la L. 170/2010 con il D.M. 5669/2011 e le Linee guida
/// allegate, e il D.I. 182/2020 per il PEI. **Vanno riviste da un docente di
/// sostegno prima della vendita**: sono responsabilità professionale sua, non
/// di chi scrive il software.
public nonisolated enum MeasureCatalog {

    private static let linee = "L. 170/2010 — D.M. 5669/2011, Linee guida"
    private static let pei = "D.I. 182/2020 — L. 104/1992"

    /// Cosa si dà all'alunno perché possa fare la stessa cosa degli altri.
    public static let compensative: [DidacticMeasure] = [
        .init(id: "comp.sintesi-vocale", text: "Sintesi vocale per la lettura autonoma dei testi", reference: linee, category: .compensative),
        .init(id: "comp.audiolibri", text: "Testi in formato digitale e audiolibri", reference: linee, category: .compensative),
        .init(id: "comp.registrazione", text: "Registrazione delle lezioni", reference: linee, category: .compensative),
        .init(id: "comp.videoscrittura", text: "Videoscrittura con correttore ortografico", reference: linee, category: .compensative),
        .init(id: "comp.computer-verifiche", text: "Uso del computer personale nelle prove scritte", reference: linee, category: .compensative),
        .init(id: "comp.calcolatrice", text: "Calcolatrice non programmabile", reference: linee, category: .compensative),
        .init(id: "comp.formulari", text: "Formulari, tabelle e schemi durante le verifiche", reference: linee, category: .compensative),
        .init(id: "comp.mappe", text: "Mappe concettuali fornite dal docente o predisposte dall'alunno", reference: linee, category: .compensative),
        .init(id: "comp.tavola-pitagorica", text: "Tavola pitagorica e tabella delle misure", reference: linee, category: .compensative),
        .init(id: "comp.dizionario", text: "Dizionario digitale", reference: linee, category: .compensative),
        .init(id: "comp.software", text: "Software didattici specifici", reference: linee, category: .compensative)
    ]

    /// Da cosa si esonera l'alunno, perché non misura ciò che si vuole valutare.
    public static let dispensative: [DidacticMeasure] = [
        .init(id: "disp.lettura-alta-voce", text: "Dispensa dalla lettura ad alta voce in classe", reference: linee, category: .dispensative),
        .init(id: "disp.dettatura", text: "Dispensa dalla scrittura veloce sotto dettatura", reference: linee, category: .dispensative),
        .init(id: "disp.appunti", text: "Dispensa dal prendere appunti", reference: linee, category: .dispensative),
        .init(id: "disp.copiatura", text: "Dispensa dalla copiatura dalla lavagna", reference: linee, category: .dispensative),
        .init(id: "disp.memorizzazione", text: "Dispensa dallo studio mnemonico di tabelle, formule, date e definizioni", reference: linee, category: .dispensative),
        .init(id: "disp.tempi", text: "Tempi aggiuntivi fino al 30% per le prove scritte", reference: linee, category: .dispensative),
        .init(id: "disp.quantita", text: "Riduzione quantitativa degli esercizi, senza riduzione degli obiettivi", reference: linee, category: .dispensative),
        .init(id: "disp.ortografia", text: "Non valutazione della correttezza ortografica e della calligrafia", reference: linee, category: .dispensative),
        .init(id: "disp.lingua-straniera", text: "Dispensa dalla lingua straniera in forma scritta, nei casi previsti", reference: linee, category: .dispensative)
    ]

    /// Come si conduce e si valuta una prova.
    public static let assessment: [DidacticMeasure] = [
        .init(id: "val.programmate", text: "Verifiche e interrogazioni programmate e concordate", reference: linee, category: .assessment),
        .init(id: "val.strutturate", text: "Prevalenza di prove strutturate: scelta multipla, vero/falso, completamento", reference: linee, category: .assessment),
        .init(id: "val.lettura-consegna", text: "Lettura del testo della prova da parte del docente", reference: linee, category: .assessment),
        .init(id: "val.strumenti-in-prova", text: "Uso di mappe, schemi e formulari durante la prova", reference: linee, category: .assessment),
        .init(id: "val.contenuto", text: "Valutazione del contenuto e non della forma", reference: linee, category: .assessment),
        .init(id: "val.orale-compensa", text: "Compensazione di una prova scritta con una prova orale", reference: linee, category: .assessment),
        .init(id: "val.suddivisione", text: "Suddivisione della prova in parti somministrate separatamente", reference: pei, category: .assessment)
    ]

    public static var all: [DidacticMeasure] { compensative + dispensative + assessment }

    public static func measure(id: String) -> DidacticMeasure? {
        all.first { $0.id == id }
    }

    /// Ritrova nel catalogo una misura salvata come testo libero.
    ///
    /// Le schede create prima del catalogo contengono diciture scritte a mano
    /// ("Tempo aggiuntivo +30%"): senza questo, riaprendole comparirebbero
    /// come non spuntate e il docente crederebbe di aver perso la
    /// configurazione dell'alunno.
    public static func matching(_ text: String) -> DidacticMeasure? {
        if let byId = all.first(where: { $0.id == text }) { return byId }

        let needle = tokens(of: text)
        guard !needle.isEmpty else { return nil }

        // Si confrontano le parole, non le sottostringhe: "Tempo aggiuntivo
        // +30%" e "Tempi aggiuntivi fino al 30%" sono la stessa misura, ma
        // in italiano singolare e plurale cambiano l'ultima lettera e nessun
        // contains() le vede uguali.
        let scored = all
            .map { (measure: $0, score: overlap(needle, tokens(of: $0.text))) }
            .filter { $0.score >= 0.5 }
            .sorted { $0.score > $1.score }

        return scored.first?.measure
    }

    /// Quante parole della dicitura salvata ritrovo nella misura di catalogo.
    private static func overlap(_ needle: [String], _ hay: [String]) -> Double {
        guard !needle.isEmpty else { return 0 }
        let found = needle.filter { word in hay.contains { sameWord($0, word) } }
        return Double(found.count) / Double(needle.count)
    }

    /// Due parole sono la stessa se coincidono a meno della coda flessiva.
    /// La soglia cresce con la lunghezza, così "computer" e "compensativi"
    /// non finiscono per essere la stessa parola solo perché iniziano uguale.
    private static func sameWord(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let common = max(4, min(a.count, b.count) - 2)
        guard a.count >= common, b.count >= common else { return false }
        return a.prefix(common) == b.prefix(common)
    }

    /// Parole portanti: si scartano le corte, che sono articoli e preposizioni.
    private static func tokens(of text: String) -> [String] {
        normalized(text).split(separator: " ").map(String.init).filter { $0.count >= 4 }
    }

    private static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
        let letters = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(letters).split(separator: " ").joined(separator: " ")
    }
}
