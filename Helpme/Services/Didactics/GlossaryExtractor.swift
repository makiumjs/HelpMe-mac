import Foundation
import NaturalLanguage

public nonisolated struct GlossaryTerm: Equatable, Sendable {
    public let term: String
    public let context: String
    public let occurrences: Int
}
public nonisolated enum GlossaryExtractor {
    private static let technicalSuffixes = [
        "zione", "sione", "mento", "ità", "ismo", "logia", "grafia",
        "metro", "sfera", "tudine", "enza", "anza", "genesi", "crazia"
    ]
    private static let functionWords: Set<String> = [
        "senza", "sopra", "sotto", "dopo", "prima", "dentro", "fuori", "contro",
        "verso", "oltre", "invece", "quindi", "mentre", "perche", "poiche",
        "dunque", "inoltre", "infatti", "anche", "ancora", "sempre", "quando",
        "dove", "come", "quale", "quali", "questo", "questa", "questi", "queste",
        "quello", "quella", "quelli", "quelle", "altro", "altra", "altri", "altre",
        "stesso", "stessa", "molto", "molti", "poco", "pochi", "tutto", "tutti"
    ]
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
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
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
    static func score(_ word: String, occurrences: Int) -> Int {
        var score = occurrences * 3
        if technicalSuffixes.contains(where: { word.hasSuffix($0) }) { score += 5 }
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

nonisolated extension String {
    var capitalizedFirstLetter: String { prefix(1).uppercased() + dropFirst() }
}
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
                .replacingOccurrences(of: "_", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if definition.count >= 3 { result[term.lowercased()] = definition }
            currentTerm = nil
        }
        return result
    }
}
