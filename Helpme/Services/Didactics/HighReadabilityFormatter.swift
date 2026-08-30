import Foundation
public nonisolated enum HighReadabilityFormatter {

    public static func format(_ text: String) -> String {
        let paragraphs = GlossaryExtractor.joinWrappedLines(text)
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        return paragraphs
            .map { paragraph in
                ReadabilityAnalyzer.sentencesOf(paragraph)
                    .map(asLine)
                    .joined(separator: "\n\n")
            }
            .joined(separator: "\n\n---\n\n")
    }
    static func asLine(_ sentence: String) -> String {
        guard let list = asList(sentence) else { return sentence }
        return list
    }

    static func asList(_ sentence: String) -> String? {
        guard let colon = sentence.firstIndex(of: ":") else { return nil }
        let head = String(sentence[sentence.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
        var tail = String(sentence[sentence.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !head.isEmpty, !tail.isEmpty else { return nil }

        if tail.hasSuffix(".") { tail.removeLast() }
        let pieces = tail
            .replacingOccurrences(of: " e ", with: ", ", options: [.backwards, .caseInsensitive])
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard pieces.count >= 3, pieces.allSatisfy({ $0.count <= 60 }) else { return nil }
        return "\(head):\n\n" + pieces.map { "- \($0)" }.joined(separator: "\n")
    }
}
public nonisolated enum ClearTextComposer {

    public static func compose(_ text: String, glossary: [String: String] = [:]) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Incolla il testo da rendere leggibile."
        }

        let report = ReadabilityAnalyzer.analyze(trimmed)
        var parts = ["## Testo ad alta leggibilità", HighReadabilityFormatter.format(trimmed)]

        parts.append("""
        ---

        ## Che cosa resta da semplificare

        **Indice Gulpease: \(report.gulpease)/100.** \(report.verdict)
        Frasi: \(report.sentences.count), in media \(report.averageWords) parole ciascuna.
        """)

        let daRivedere = report.sentencesNeedingWork
        if daRivedere.isEmpty {
            parts.append("*Nessuna frase da segnalare: il testo regge così com'è.*")
        } else {
            let righe = daRivedere.prefix(12).enumerated().map { index, sentence in
                "**\(index + 1).** \(sentence.text)\n\n   *\(sentence.reasons.joined(separator: " · "))*"
            }
            parts.append(righe.joined(separator: "\n\n"))
        }

        if let suggerimenti = substitutions(for: report, glossary: glossary) {
            parts.append(suggerimenti)
        }

        parts.append("""
        ---

        *L'app ha reso il testo leggibile — una frase per riga, elenchi al posto \
        delle enumerazioni — e ha misurato dov'è difficile. **Le frasi qui sopra \
        vanno riscritte a mano:** semplificare il lessico richiede di sapere quali \
        parole quell'alunno ha già, e non si indovina.*
        """)

        return parts.joined(separator: "\n\n")
    }
    static func substitutions(for report: ReadabilityReport, glossary: [String: String]) -> String? {
        guard !glossary.isEmpty else { return nil }

        let difficili = Set(report.sentencesNeedingWork.flatMap(\.rareWords))
        let disponibili = glossary
            .filter { difficili.contains($0.key.lowercased()) }
            .sorted { $0.key < $1.key }

        guard !disponibili.isEmpty else { return nil }
        let righe = disponibili.map { "- **\($0.key)** → \($0.value)" }
        return """
        ### Parole che hai già spiegato per questo alunno

        \(righe.joined(separator: "\n"))

        *Dal glossario di questo alunno: usale al posto del termine tecnico, \
        o subito dopo fra parentesi.*
        """
    }
}
