import Foundation
public nonisolated struct SimplificationRow: Identifiable, Equatable {
    public let id = UUID()
    public let original: String
    public var rewritten: String = ""
    public let reading: SentenceReading
    public let endsParagraph: Bool
    public var final: String {
        let clean = rewritten.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? original : clean
    }

    public var isRewritten: Bool { !rewritten.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
public nonisolated enum SimplificationDraft {

    public static func rows(from text: String) -> [SimplificationRow] {
        let paragraphs = SentenceSplitter.joinWrappedLines(text)
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return paragraphs.flatMap { paragraph -> [SimplificationRow] in
            let sentences = SentenceSplitter.sentences(in: paragraph)
            return sentences.enumerated().map { index, sentence in
                SimplificationRow(
                    original: sentence,
                    reading: ReadabilityAnalyzer.reading(of: sentence),
                    endsParagraph: index == sentences.count - 1
                )
            }
        }
    }
    public static func assemble(_ rows: [SimplificationRow]) -> String {
        var paragraphs: [String] = []
        var current: [String] = []

        for row in rows {
            current.append(row.final)
            if row.endsParagraph {
                paragraphs.append(current.joined(separator: "\n\n"))
                current = []
            }
        }
        if !current.isEmpty { paragraphs.append(current.joined(separator: "\n\n")) }
        return paragraphs.joined(separator: "\n\n---\n\n")
    }
    public static func currentGulpease(_ rows: [SimplificationRow]) -> Int {
        let text = rows.map(\.final).joined(separator: " ")
        return ReadabilityAnalyzer.gulpease(text, sentenceCount: max(1, rows.count))
    }
    public static func hints(for row: SimplificationRow, glossary: [String: String]) -> [(String, String)] {
        row.reading.rareWords.compactMap { word in
            glossary[word.lowercased()].map { (word, $0) }
        }
    }
}
