import Foundation
import NaturalLanguage

nonisolated public enum SentenceSplitter {

    /// Un testo copiato da un libro va a capo dove finisce la riga, non dove
    /// finisce la frase: senza ricucirlo si estraggono mezze frasi.
    public static func joinWrappedLines(_ text: String) -> String {
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

    public static func sentences(in text: String, minimumLength: Int = 0) -> [String] {
        let flowing = joinWrappedLines(text)
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = flowing
        tokenizer.enumerateTokens(in: flowing.startIndex..<flowing.endIndex) { range, _ in
            let sentence = flowing[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count > minimumLength { sentences.append(sentence) }
            return true
        }
        return sentences
    }
}
