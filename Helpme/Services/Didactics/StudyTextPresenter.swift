import Foundation
public nonisolated enum StudyTextPresenter {

    public static func readable(_ content: String) -> String {
        guard !content.isEmpty else { return content }

        var lines: [String] = []

        for rawLine in content.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                lines.append("")
                continue
            }
            if trimmed.hasPrefix("#") {
                let title = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { lines.append(title) }
                continue
            }

            if let option = quizOption(in: trimmed) {
                lines.append("• " + option)
                continue
            }

            lines.append(readableSeparators(in: rawLine))
        }
        var compacted: [String] = []
        for line in lines {
            if line.isEmpty && (compacted.last?.isEmpty ?? true) { continue }
            compacted.append(line)
        }
        while compacted.last?.isEmpty == true { compacted.removeLast() }

        return compacted.joined(separator: "\n")
    }
    public static func handout(_ content: String) -> String {
        guard !content.isEmpty else { return content }

        let lines = content.components(separatedBy: .newlines).map { rawLine -> String in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if let option = DidacticMarkup.quizOption(in: trimmed) {
                let indent = String(rawLine.prefix(while: { $0 == " " || $0 == "\t" }))
                return indent + option.bullet + option.text
            }

            return readableSeparators(in: rawLine)
        }

        return lines.joined(separator: "\n")
    }
    public static func answerKey(from content: String) -> String? {
        let questions = QuizParser.parse(content)
        guard !questions.isEmpty else { return nil }

        var lines: [String] = [
            "## Chiave di correzione",
            "",
            "*Foglio per il docente — non consegnare allo studente.*",
            ""
        ]

        for (index, question) in questions.enumerated() {
            guard let correct = question.correctOption else { continue }

            lines.append("**\(index + 1).** \(question.prompt)")
            lines.append("Risposta corretta: **\(correct.text)**")
            if let explanation = correct.explanation, !explanation.isEmpty {
                lines.append(explanation)
            }
            lines.append("")
        }

        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
    private static func readableSeparators(in line: String) -> String {
        var output = line
        for separator in [" :: ", "::"] {
            output = output.replacingOccurrences(of: separator, with: " — ")
        }
        return output
    }
    private static func quizOption(in line: String) -> String? {
        DidacticMarkup.quizOption(in: line)?.text
    }
}
