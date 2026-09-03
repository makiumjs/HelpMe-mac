import Foundation
import NaturalLanguage
public nonisolated struct SentenceReading: Equatable, Sendable {
    public let text: String
    public let wordCount: Int
    public let rareWords: [String]
    public let subordinates: Int
    public let hasPassive: Bool
    public let hasDoubleNegation: Bool
    public let simplifications: [WordSimplification]
    public var isTooLong: Bool { wordCount > 20 }

    public init(
        text: String,
        wordCount: Int,
        rareWords: [String],
        subordinates: Int,
        hasPassive: Bool,
        hasDoubleNegation: Bool = false,
        simplifications: [WordSimplification] = []
    ) {
        self.text = text
        self.wordCount = wordCount
        self.rareWords = rareWords
        self.subordinates = subordinates
        self.hasPassive = hasPassive
        self.hasDoubleNegation = hasDoubleNegation
        self.simplifications = simplifications
    }

    public var needsWork: Bool { isTooLong || subordinates > 2 || hasPassive || hasDoubleNegation || !rareWords.isEmpty || !simplifications.isEmpty }
    public var reasons: [String] {
        var reasons: [String] = []
        if isTooLong { reasons.append("lunga \(wordCount) parole") }
        if subordinates > 2 { reasons.append("\(subordinates) subordinate annidate") }
        if hasPassive { reasons.append("forma passiva") }
        if hasDoubleNegation { reasons.append("doppia negazione") }
        if !simplifications.isEmpty {
            reasons.append("sinonimi: " + simplifications.map { "\($0.complexWord) → \($0.suggestedAlternative)" }.joined(separator: ", "))
        } else if !rareWords.isEmpty {
            reasons.append("parole difficili: " + rareWords.joined(separator: ", "))
        }
        return reasons
    }
}

public nonisolated struct ReadabilityReport: Equatable, Sendable {
    public let sentences: [SentenceReading]
    public let gulpease: Int
    public var sentencesNeedingWork: [SentenceReading] { sentences.filter(\.needsWork) }
    public var averageWords: Int {
        guard !sentences.isEmpty else { return 0 }
        return sentences.map(\.wordCount).reduce(0, +) / sentences.count
    }
    public var verdict: String {
        switch gulpease {
        case 80...:  return "Molto leggibile: adatto anche a chi legge con fatica."
        case 60..<80: return "Leggibile alle superiori. Per un alunno con dislessia conviene salire ancora."
        case 40..<60: return "Difficile per una terza media: le frasi segnalate qui sotto sono il motivo."
        default:      return "Difficile anche per un diploma. Va riscritto, non solo riformattato."
        }
    }
}
public nonisolated enum ReadabilityAnalyzer {

    public static func analyze(_ text: String) -> ReadabilityReport {
        let sentences = SentenceSplitter.sentences(in: text).map(reading(of:))
        return ReadabilityReport(sentences: sentences, gulpease: gulpease(text, sentenceCount: sentences.count))
    }
    static func gulpease(_ text: String, sentenceCount: Int) -> Int {
        let letters = text.filter(\.isLetter).count
        let words = wordsOf(text).count
        guard words > 0, sentenceCount > 0 else { return 0 }

        let value = 89.0 + (300.0 * Double(sentenceCount) - 10.0 * Double(letters)) / Double(words)
        return min(100, max(0, Int(value.rounded())))
    }

    static func reading(of sentence: String) -> SentenceReading {
        let words = wordsOf(sentence)
        let simpls = CognitiveLoadAnalyzer.findSimplifications(in: sentence)
        return SentenceReading(
            text: sentence,
            wordCount: words.count,
            rareWords: words
                .map { withoutElision($0.lowercased()) }
                .filter { $0.count >= 5 && !GlossaryExtractor.isCommonItalian($0) }
                .reduce(into: [String]()) { unique, word in if !unique.contains(word) { unique.append(word) } },
            subordinates: words.filter { subordinatingWords.contains($0.lowercased()) }.count,
            hasPassive: hasPassive(sentence),
            hasDoubleNegation: CognitiveLoadAnalyzer.hasDoubleNegation(sentence),
            simplifications: simpls
        )
    }

    private static let subordinatingWords: Set<String> = [
        "che", "cui", "quale", "quali", "poiché", "perché", "affinché", "sebbene",
        "benché", "mentre", "quando", "qualora", "nonostante", "purché", "finché"
    ]
    static func hasPassive(_ sentence: String) -> Bool {
        let words = wordsOf(sentence).map { $0.lowercased() }
        let auxiliaries: Set<String> = ["viene", "vengono", "veniva", "venivano",
                                        "è", "sono", "era", "erano", "fu", "furono"]
        let participleEndings = ["ato", "ata", "ati", "ate", "ito", "ita", "iti", "ite",                                "uto", "uta", "uti", "ute", "so", "sa", "si", "se"]

        for (index, word) in words.enumerated() where auxiliaries.contains(word) {
            for offset in 1...2 where index + offset < words.count {
                let candidate = words[index + offset]
                if candidate.count >= 5, participleEndings.contains(where: { candidate.hasSuffix($0) }) {
                    return true
                }
            }
        }
        return false
    }

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
