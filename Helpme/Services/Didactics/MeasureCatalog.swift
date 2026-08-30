import Foundation
public nonisolated enum MeasureCategory: String, Sendable {
    case compensative
    case dispensative
    case assessment
}

public nonisolated struct DidacticMeasure: Identifiable, Hashable, Sendable {
    public let id: String
    public let text: String
    public let reference: String
    public let category: MeasureCategory

    public init(id: String, text: String, reference: String, category: MeasureCategory) {
        self.id = id
        self.text = text
        self.reference = reference
        self.category = category
    }
}
public nonisolated enum MeasureCatalog {

    private static let linee = "L. 170/2010 — D.M. 5669/2011, Linee guida"
    private static let pei = "D.I. 182/2020 come modificato dal D.I. 153/2023 — D.Lgs. 66/2017"
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
    public static let usableDuringTest: Set<String> = [
        "comp.calcolatrice",
        "comp.formulari",
        "comp.mappe",
        "comp.tavola-pitagorica",
        "comp.dizionario",
        "comp.computer-verifiche",
        "comp.sintesi-vocale"
    ]

    public static func measure(id: String) -> DidacticMeasure? {
        all.first { $0.id == id }
    }
    public static func matching(_ text: String) -> DidacticMeasure? {
        if let byId = all.first(where: { $0.id == text }) { return byId }

        let needle = tokens(of: text)
        guard !needle.isEmpty else { return nil }
        let scored = all
            .map { (measure: $0, score: overlap(needle, tokens(of: $0.text))) }
            .filter { $0.score >= 0.5 }
            .sorted { $0.score > $1.score }

        return scored.first?.measure
    }
    private static func overlap(_ needle: [String], _ hay: [String]) -> Double {
        guard !needle.isEmpty else { return 0 }
        let found = needle.filter { word in hay.contains { sameWord($0, word) } }
        return Double(found.count) / Double(needle.count)
    }
    private static func sameWord(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let common = max(4, min(a.count, b.count) - 2)
        guard a.count >= common, b.count >= common else { return false }
        return a.prefix(common) == b.prefix(common)
    }
    private static func tokens(of text: String) -> [String] {
        normalized(text).split(separator: " ").map(String.init).filter { $0.count >= 4 }
    }

    private static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
        let letters = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(letters).split(separator: " ").joined(separator: " ")
    }
}
