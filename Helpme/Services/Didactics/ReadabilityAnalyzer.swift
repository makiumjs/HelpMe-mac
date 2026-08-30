import Foundation
import NaturalLanguage

/// Cosa rende difficile una frase, e quanto.
public nonisolated struct SentenceReading: Equatable, Sendable {
    public let text: String
    public let wordCount: Int
    /// Parole che il vocabolario italiano di sistema non conosce: quasi
    /// sempre tecnicismi da spiegare o da sostituire.
    public let rareWords: [String]
    /// Congiunzioni subordinanti: più di due e il periodo si annida.
    public let subordinates: Int
    public let hasPassive: Bool

    /// Oltre venti parole una frase smette di reggersi in memoria di lavoro
    /// mentre la si legge — la soglia delle linee guida Easy-to-Read.
    public var isTooLong: Bool { wordCount > 20 }

    public var needsWork: Bool { isTooLong || subordinates > 2 || hasPassive || !rareWords.isEmpty }

    /// Perché questa frase è segnalata, in parole d'uso.
    public var reasons: [String] {
        var reasons: [String] = []
        if isTooLong { reasons.append("lunga \(wordCount) parole") }
        if subordinates > 2 { reasons.append("\(subordinates) subordinate annidate") }
        if hasPassive { reasons.append("forma passiva") }
        if !rareWords.isEmpty {
            reasons.append("parole difficili: " + rareWords.joined(separator: ", "))
        }
        return reasons
    }
}

public nonisolated struct ReadabilityReport: Equatable, Sendable {
    public let sentences: [SentenceReading]
    /// Indice Gulpease: la formula tarata sull'italiano, non una traduzione
    /// del Flesch inglese. Da 0 a 100, più alto è più facile.
    public let gulpease: Int

    public var sentencesNeedingWork: [SentenceReading] { sentences.filter(\.needsWork) }
    public var averageWords: Int {
        guard !sentences.isEmpty else { return 0 }
        return sentences.map(\.wordCount).reduce(0, +) / sentences.count
    }

    /// Cosa vuol dire quel numero per chi legge, non per chi misura.
    ///
    /// Le soglie sono quelle d'uso comune dell'indice: sotto 40 un testo è
    /// difficile anche per un diploma, sotto 60 lo è per una terza media.
    public var verdict: String {
        switch gulpease {
        case 80...:  return "Molto leggibile: adatto anche a chi legge con fatica."
        case 60..<80: return "Leggibile alle superiori. Per un alunno con dislessia conviene salire ancora."
        case 40..<60: return "Difficile per una terza media: le frasi segnalate qui sotto sono il motivo."
        default:      return "Difficile anche per un diploma. Va riscritto, non solo riformattato."
        }
    }
}

/// Misura quanto un testo è difficile e dice dove.
///
/// Non riscrive niente: riscrivere richiede di sapere cosa quell'alunno ha
/// già in testa, e resta al docente. Questo dice *quali* frasi sono il
/// problema e *perché*, così il lavoro va dove serve invece che ovunque.
public nonisolated enum ReadabilityAnalyzer {

    public static func analyze(_ text: String) -> ReadabilityReport {
        let sentences = sentencesOf(text).map(reading(of:))
        return ReadabilityReport(sentences: sentences, gulpease: gulpease(text, sentenceCount: sentences.count))
    }

    /// Gulpease = 89 + (300 × frasi − 10 × lettere) / parole.
    static func gulpease(_ text: String, sentenceCount: Int) -> Int {
        let letters = text.filter(\.isLetter).count
        let words = wordsOf(text).count
        guard words > 0, sentenceCount > 0 else { return 0 }

        let value = 89.0 + (300.0 * Double(sentenceCount) - 10.0 * Double(letters)) / Double(words)
        return min(100, max(0, Int(value.rounded())))
    }

    static func reading(of sentence: String) -> SentenceReading {
        let words = wordsOf(sentence)
        return SentenceReading(
            text: sentence,
            wordCount: words.count,
            rareWords: words
                .map { withoutElision($0.lowercased()) }
                .filter { $0.count >= 5 && !GlossaryExtractor.isCommonItalian($0) }
                .reduce(into: [String]()) { unique, word in if !unique.contains(word) { unique.append(word) } },
            subordinates: words.filter { subordinatingWords.contains($0.lowercased()) }.count,
            hasPassive: hasPassive(sentence)
        )
    }

    private static let subordinatingWords: Set<String> = [
        "che", "cui", "quale", "quali", "poiché", "perché", "affinché", "sebbene",
        "benché", "mentre", "quando", "qualora", "nonostante", "purché", "finché"
    ]

    /// "viene applicata", "è stato costruito", "sono considerati".
    ///
    /// Il passivo allontana chi agisce dall'azione, e chi legge con fatica
    /// perde proprio quello: chi fa che cosa.
    static func hasPassive(_ sentence: String) -> Bool {
        let words = wordsOf(sentence).map { $0.lowercased() }
        let auxiliaries: Set<String> = ["viene", "vengono", "veniva", "venivano",
                                        "è", "sono", "era", "erano", "fu", "furono"]
        let participleEndings = ["ato", "ata", "ati", "ate", "ito", "ita", "iti", "ite",
                                 "uto", "uta", "uti", "ute", "so", "sa", "si", "se"]

        for (index, word) in words.enumerated() where auxiliaries.contains(word) {
            // "è stato costruito": si guarda anche la parola dopo l'ausiliare.
            for offset in 1...2 where index + offset < words.count {
                let candidate = words[index + offset]
                if candidate.count >= 5, participleEndings.contains(where: { candidate.hasSuffix($0) }) {
                    return true
                }
            }
        }
        return false
    }

    static func sentencesOf(_ text: String) -> [String] {
        let flowing = GlossaryExtractor.joinWrappedLines(text)
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = flowing
        tokenizer.enumerateTokens(in: flowing.startIndex..<flowing.endIndex) { range, _ in
            let sentence = flowing[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            return true
        }
        return sentences
    }

    /// Toglie l'articolo elisa: "l'astenosfera" e' la parola "astenosfera".
    ///
    /// Senza questo la parola restava attaccata al suo articolo, quindi non
    /// risultava rara e il glossario dell'alunno non la ritrovava. Si conta
    /// pero' come una parola sola nell'indice, che e' come Gulpease vuole.
    static func withoutElision(_ word: String) -> String {
        guard let apostrophe = word.firstIndex(where: { $0 == "\u{2019}" || $0 == "'" }) else { return word }
        let prefix = word[word.startIndex..<apostrophe]
        let rest = String(word[word.index(after: apostrophe)...])
        return (prefix.count <= 5 && !rest.isEmpty) ? rest : word
    }

    static func wordsOf(_ text: String) -> [String] {
        text.split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .map(String.init)
            .filter { $0.contains(where: \.isLetter) }
    }
}
