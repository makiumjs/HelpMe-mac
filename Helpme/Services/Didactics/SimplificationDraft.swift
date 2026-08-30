import Foundation

/// Una frase del testo, con la sua eventuale riscrittura.
public struct SimplificationRow: Identifiable, Equatable {
    public let id = UUID()
    public let original: String
    public var rewritten: String = ""
    public let reading: SentenceReading
    /// Vero sull'ultima frase di un paragrafo: serve a rimontare il testo
    /// com'era diviso, invece di appiattirlo in un blocco unico.
    public let endsParagraph: Bool

    /// Quella che finisce nel testo: la riscrittura se c'è, l'originale se no.
    public var final: String {
        let clean = rewritten.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? original : clean
    }

    public var isRewritten: Bool { !rewritten.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// Il cantiere: le frasi difficili di un testo, una per volta.
///
/// È il passo dopo la misurazione. L'analizzatore dice *quali* frasi sono il
/// problema; qui il docente le riscrive, vedendo l'originale sopra e l'indice
/// che si muove mentre lavora. Il testo si rimonta da solo: le frasi non
/// toccate restano come stavano, e non c'è nessun copia-incolla da sbagliare.
public nonisolated enum SimplificationDraft {

    public static func rows(from text: String) -> [SimplificationRow] {
        let paragraphs = GlossaryExtractor.joinWrappedLines(text)
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return paragraphs.flatMap { paragraph -> [SimplificationRow] in
            let sentences = ReadabilityAnalyzer.sentencesOf(paragraph)
            return sentences.enumerated().map { index, sentence in
                SimplificationRow(
                    original: sentence,
                    reading: ReadabilityAnalyzer.reading(of: sentence),
                    endsParagraph: index == sentences.count - 1
                )
            }
        }
    }

    /// Rimonta il testo: una frase per riga, i paragrafi dove stavano.
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

    /// L'indice del testo così com'è adesso, riscritture comprese.
    public static func currentGulpease(_ rows: [SimplificationRow]) -> Int {
        let text = rows.map(\.final).joined(separator: " ")
        return ReadabilityAnalyzer.gulpease(text, sentenceCount: max(1, rows.count))
    }

    /// Le parole difficili di questa frase che il docente ha già spiegato per
    /// quell'alunno: mostrate accanto alla casella, sono l'aiuto che serve
    /// proprio mentre si riscrive.
    public static func hints(for row: SimplificationRow, glossary: [String: String]) -> [(String, String)] {
        row.reading.rareWords.compactMap { word in
            glossary[word.lowercased()].map { (word, $0) }
        }
    }
}
