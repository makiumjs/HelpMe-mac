import Foundation
import NaturalLanguage

/// Un termine candidato per il glossario, con la frase in cui compare.
public nonisolated struct GlossaryTerm: Equatable, Sendable {
    public let term: String
    /// La frase del testo in cui il termine compare per la prima volta: serve
    /// al docente per scrivere la definizione senza tornare al libro.
    public let context: String
    public let occurrences: Int
}

/// Trova i termini tecnici di un testo, senza modello linguistico.
///
/// La parte noiosa del glossario è scovare i termini e ripescare la frase in
/// cui compaiono. La parte che vale — dirlo in parole che quell'alunno
/// capisce, e trovare l'analogia con quello che gli interessa — richiede di
/// conoscerlo, e resta al docente.
///
/// Il riconoscimento usa l'analizzatore grammaticale di sistema per tenere
/// solo i sostantivi, e poi pesa: quante volte il termine torna, se ha una
/// terminazione da termine tecnico, quanto è lungo. Non è "capire" il testo,
/// è contare — ma su un capitolo di scienze porta a galla le stesse parole
/// che sottolineerebbe un insegnante.
public nonisolated enum GlossaryExtractor {

    /// Terminazioni che in italiano segnalano un tecnicismo quasi sempre.
    private static let technicalSuffixes = [
        "zione", "sione", "mento", "ità", "ismo", "logia", "grafia",
        "metro", "sfera", "tudine", "enza", "anza", "genesi", "crazia"
    ]

    /// Parole che l'analizzatore grammaticale a volte etichetta come
    /// sostantivi pur non essendolo: "senza" era finito fra i termini da
    /// spiegare in un glossario di scienze.
    private static let functionWords: Set<String> = [
        "senza", "sopra", "sotto", "dopo", "prima", "dentro", "fuori", "contro",
        "verso", "oltre", "invece", "quindi", "mentre", "perche", "poiche",
        "dunque", "inoltre", "infatti", "anche", "ancora", "sempre", "quando",
        "dove", "come", "quale", "quali", "questo", "questa", "questi", "queste",
        "quello", "quella", "quelli", "quelle", "altro", "altra", "altri", "altre",
        "stesso", "stessa", "molto", "molti", "poco", "pochi", "tutto", "tutti"
    ]

    /// Parole grammaticali e nomi generici che un glossario non spiega.
    private static let ignored: Set<String> = [
        "cosa", "cose", "modo", "modi", "parte", "parti", "caso", "casi",
        "volta", "volte", "tipo", "tipi", "esempio", "esempi", "punto", "punti",
        "anno", "anni", "giorno", "giorni", "tempo", "tempi", "luogo", "luoghi",
        "persona", "persone", "gruppo", "gruppi", "numero", "numeri", "nome",
        "nomi", "fine", "inizio", "seguito", "causa", "effetto", "opera",
        "lavoro", "vita", "mondo", "uomo", "uomini", "donna", "donne", "testo",
        "pagina", "capitolo", "libro", "quesito", "domanda", "risposta"
    ]

    public static func extract(from text: String, limit: Int = 15) -> [GlossaryTerm] {
        let sentences = splitIntoSentences(text)
        guard !sentences.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        var firstSentence: [String: String] = [:]
        var display: [String: String] = [:]

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        tagger.setLanguage(.italian, range: text.startIndex..<text.endIndex)

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace, .omitOther]
        ) { tag, range in
            guard tag == .noun else { return true }

            let word = String(text[range])
            let key = word.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                   locale: Locale(identifier: "it_IT"))
            guard key.count >= 5, !ignored.contains(key), !functionWords.contains(key),
                  !key.contains(where: \.isNumber) else { return true }

            // Il lemma unisce "placca" e "placche", "terremoto" e "terremoti":
            // sono una voce sola di glossario, non due.
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
            // L'analizzatore a volte etichetta un verbo coniugato come
            // sostantivo: "il magma risale" produceva la voce "ridere". Se il
            // lemma e' un infinito ma la parola nel testo non lo e', quello
            // che abbiamo davanti e' un verbo, non un termine da spiegare.
            // "Cratere" e "potere" restano, perche' li' anche la parola nel
            // testo finisce cosi'.
            if let lemma, isInfinitive(lemma), !isInfinitive(key) { return true }

            let entryKey = lemma.map {
                $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            } ?? key

            counts[entryKey, default: 0] += 1
            if firstSentence[entryKey] == nil {
                display[entryKey] = (lemma ?? word).lowercased()
                firstSentence[entryKey] = sentences.first { $0.localizedCaseInsensitiveContains(word) } ?? sentences[0]
            }
            return true
        }

        return counts
            .map { key, count in
                (key: key, score: score(key, occurrences: count), count: count)
            }
            .sorted { ($0.score, $0.key) > ($1.score, $1.key) }
            .prefix(limit)
            .map { entry in
                GlossaryTerm(
                    term: display[entry.key] ?? entry.key,
                    context: firstSentence[entry.key] ?? "",
                    occurrences: entry.count
                )
            }
    }

    /// Un termine pesa di più se torna nel testo, se ha una terminazione
    /// tecnica e se è lungo. Le tre cose insieme separano "litosfera" da
    /// "insieme" meglio di ciascuna da sola.
    static func score(_ word: String, occurrences: Int) -> Int {
        var score = occurrences * 3
        if technicalSuffixes.contains(where: { word.hasSuffix($0) }) { score += 5 }
        // Una parola che il vocabolario italiano di sistema non conosce e'
        // quasi sempre un tecnicismo: "litosfera" e "subduzione" non ci sono,
        // "strato" e "movimento" si'. Il contrario pero' non vale - "magma" e
        // "faglia" ci sono e vanno spiegati lo stesso - quindi e' una spinta,
        // non un criterio.
        if !isCommonItalian(word) { score += 8 }
        if word.count >= 10 { score += 2 }
        return score
    }

    private static let italianVocabulary = NLEmbedding.wordEmbedding(for: .italian)

    static func isCommonItalian(_ word: String) -> Bool {
        guard let italianVocabulary else { return true }
        return italianVocabulary.vector(for: word) != nil
    }

    static func isInfinitive(_ word: String) -> Bool {
        ["are", "ere", "ire", "arsi", "ersi", "irsi"].contains { word.hasSuffix($0) }
    }

    static func splitIntoSentences(_ text: String) -> [String] {
        let flowing = joinWrappedLines(text)
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = flowing
        tokenizer.enumerateTokens(in: flowing.startIndex..<flowing.endIndex) { range, _ in
            let sentence = flowing[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count > 15 { sentences.append(sentence) }
            return true
        }
        return sentences
    }

    /// Ricuce le righe spezzate a meta' frase.
    ///
    /// Un testo copiato da un libro va a capo dove finisce la riga, non dove
    /// finisce la frase: senza ricucirlo si estraevano mezze frasi come
    /// "delle placche prende il nome di tettonica", che su un formulario da
    /// banco non servono a niente. Le righe vuote restano, perche' separano i
    /// paragrafi davvero.
    static func joinWrappedLines(_ text: String) -> String {
        var result: [String] = []
        var paragraph: [String] = []

        func closeParagraph() {
            if !paragraph.isEmpty { result.append(paragraph.joined(separator: " ")) }
            paragraph = []
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { closeParagraph() } else { paragraph.append(line) }
        }
        closeParagraph()
        return result.joined(separator: "\n\n")
    }
}

/// Impagina il glossario da compilare.
public nonisolated enum GlossaryComposer {

    public static func compose(terms: [GlossaryTerm], interest: String) -> String {
        guard !terms.isEmpty else {
            return "Non ho riconosciuto termini tecnici in questo testo. "
                 + "Serve un brano di contenuto — un capitolo, una spiegazione — non un elenco di consegne."
        }

        var parts = ["## Glossario dei termini"]

        for term in terms {
            var entry = "### \(term.term.capitalizedFirstLetter)\n\n"
            entry += "> \(term.context)\n\n"
            entry += "**Che cosa vuol dire:** _______________________________________\n\n"
            if !interest.trimmingCharacters(in: .whitespaces).isEmpty {
                entry += "**È come quando…** _______________________________ *(collega a: \(interest))*"
            } else {
                entry += "**È come quando…** _______________________________"
            }
            parts.append(entry)
        }

        parts.append("""
        ---

        *\(Plural.it(terms.count, "termine estratto dal testo", "termini estratti dal testo")), \
        in ordine di peso nel brano. La frase citata è quella in cui il termine compare \
        per la prima volta. La definizione e l'analogia le scrivi tu: dipendono da quello \
        che l'alunno sa già.*
        """)

        return parts.joined(separator: "\n\n")
    }
}

extension String {
    var capitalizedFirstLetter: String { prefix(1).uppercased() + dropFirst() }
}

/// Rilegge un glossario compilato dal docente.
///
/// Serve alla spiegazione semplificata: le parole che il docente ha gia'
/// spiegato per quell'alunno si riusano, invece di farle spiegare di nuovo a
/// qualcun altro con parole diverse.
public nonisolated enum GlossaryReader {

    private static let definitionMarker = "**Che cosa vuol dire:**"

    public static func definitions(from markdown: String) -> [String: String] {
        var result: [String: String] = [:]
        var currentTerm: String?

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("### ") {
                currentTerm = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let term = currentTerm, line.hasPrefix(definitionMarker) else { continue }
            let definition = String(line.dropFirst(definitionMarker.count))
                // Le caselle non compilate sono file di trattini bassi.
                .replacingOccurrences(of: "_", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if definition.count >= 3 { result[term.lowercased()] = definition }
            currentTerm = nil
        }
        return result
    }
}
