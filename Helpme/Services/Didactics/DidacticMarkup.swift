import Foundation

nonisolated enum DidacticMarkup {

    static let bulletPrefixes = ["- ", "* ", "+ "]

    static let detailSeparators = [" :: ", "::", " — ", " – ", " | "]

    struct QuizOption {
       
        var bullet: String
        var text: String
        var isCorrect: Bool
        var explanation: String?
    }

    static func quizOption(in line: String) -> QuizOption? {
        for bullet in bulletPrefixes {
            guard line.hasPrefix(bullet) else { continue }

            let rest = String(line.dropFirst(bullet.count))
            let lowered = rest.lowercased()

            let marker: String
            let isCorrect: Bool
            if lowered.hasPrefix("[x]")      { marker = "[x]"; isCorrect = true }
            else if lowered.hasPrefix("[ ]") { marker = "[ ]"; isCorrect = false }
            else if lowered.hasPrefix("[]")  { marker = "[]";  isCorrect = false }
            else { return nil }

            let body = String(rest.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            let (text, explanation) = splitDetail(body)
            guard !text.isEmpty else { return nil }

            return QuizOption(bullet: bullet, text: text, isCorrect: isCorrect, explanation: explanation)
        }
        return nil
    }
    static func isQuizOption(_ line: String) -> Bool {
        quizOption(in: line) != nil
    }
    static func splitDetail(_ text: String) -> (head: String, detail: String?) {
        for separator in detailSeparators {
            guard let range = text.range(of: separator) else { continue }
            let head = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let detail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !head.isEmpty && !detail.isEmpty { return (head, detail) }
        }
        return (text, nil)
    }
}
