import Foundation

public nonisolated struct ExamQuestion: Equatable, Sendable {
    public var number: String
    public var text: String
    public var points: Int?
    public var subItems: [String]

    public init(number: String, text: String, points: Int? = nil, subItems: [String] = []) {
        self.number = number
        self.text = text
        self.points = points
        self.subItems = subItems
    }
}

public nonisolated struct ExamSection: Equatable, Sendable {
    public var title: String?
    public var questions: [ExamQuestion]

    public init(title: String? = nil, questions: [ExamQuestion] = []) {
        self.title = title
        self.questions = questions
    }
}

public nonisolated struct ParsedExam: Equatable, Sendable {
    public var sections: [ExamSection]
    public var durationMinutes: Int?
    public var questions: [ExamQuestion] { sections.flatMap(\.questions) }
   
    public var declaredTotalPoints: Int?
    public var totalPoints: Int? {
        if let declaredTotalPoints { return declaredTotalPoints }
        let points = questions.compactMap(\.points)
        return points.isEmpty ? nil : points.reduce(0, +)
    }
    public var isEmpty: Bool { questions.isEmpty }
    public var title: String? {
        guard let first = sections.first, first.questions.isEmpty else { return nil }
        return first.title
    }
    public var contentSections: [ExamSection] { sections.filter { !$0.questions.isEmpty } }
}
public nonisolated enum ExamParser {

    public static func parse(_ text: String) -> ParsedExam {
        let lines = text.components(separatedBy: .newlines)
        var sections: [ExamSection] = []
        var current = ExamSection()
        var pending: ExamQuestion?

        func closeQuestion() {
            if let pending { current.questions.append(pending) }
            pending = nil
        }
        func closeSection() {
            closeQuestion()
            if current.title != nil || !current.questions.isEmpty { sections.append(current) }
            current = ExamSection()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let title = sectionTitle(in: line) {
                closeSection()
                current.title = title
                continue
            }

            if let (number, body) = questionStart(in: line) {
                closeQuestion()
                pending = ExamQuestion(number: number, text: strippingPoints(body), points: points(in: line))
                continue
            }
            if isMetadata(line) {
                closeQuestion()
                continue
            }

            if let sub = subItem(in: line), pending != nil {
                pending?.subItems.append(strippingPoints(sub))
                 if let subPoints = points(in: line) {
                    let sofar = pending?.points ?? 0
                    pending?.points = sofar + subPoints
                }
                continue
            }
            if pending != nil {
                if let extra = points(in: line), pending?.points == nil { pending?.points = extra }
                let continuation = strippingPoints(line)
                if !continuation.isEmpty {
                    pending?.text += (isStructural(line) ? "\n" : " ") + continuation
                }
            }
        }
        closeSection()

        var parsed = ParsedExam(sections: sections, durationMinutes: duration(in: text))
        parsed.declaredTotalPoints = declaredTotal(in: text)
        return parsed.isEmpty ? parseUnnumberedQuestions(text) : parsed
    }
    static func parseUnnumberedQuestions(_ text: String) -> ParsedExam {
        var section = ExamSection()
        var title: String?
        var number = 1

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "#*_-• \t"))
            guard !line.isEmpty, !isMetadata(line) else { continue }

            if line.hasSuffix("?") {
                section.questions.append(ExamQuestion(number: String(number), text: strippingPoints(line)))
                number += 1
            } else if title == nil, section.questions.isEmpty, let heading = sectionTitle(in: line) {
                title = heading
            }
        }

        guard !section.questions.isEmpty else { return ParsedExam(sections: [], durationMinutes: nil) }

        var sections: [ExamSection] = []
        if let title { sections.append(ExamSection(title: title)) }
        sections.append(section)
        var parsed = ParsedExam(sections: sections, durationMinutes: duration(in: text))
        parsed.declaredTotalPoints = declaredTotal(in: text)
        return parsed
    }

    // MARK: - Riconoscitori
    static func sectionTitle(in line: String) -> String? {
        let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: "#*_ "))
        guard !cleaned.isEmpty, cleaned.count <= 90 else { return nil }
        guard questionStart(in: cleaned) == nil else { return nil }

        let openers = ["parte ", "sezione ", "esercizi", "quesiti", "prova ", "verifica "]
        let lower = cleaned.lowercased()
        if openers.contains(where: { lower.hasPrefix($0) }) { return cleaned }
        let letters = cleaned.filter(\.isLetter)
        if !letters.isEmpty, letters.allSatisfy(\.isUppercase), !cleaned.hasSuffix(".") { return cleaned }

        return nil
    }
    static func questionStart(in line: String) -> (number: String, body: String)? {
        let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: "#*_ "))
        let digits = cleaned.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 2 else { return nil }

        var rest = Substring(cleaned.dropFirst(digits.count))
        if rest.hasPrefix(" -") || rest.hasPrefix(" –") { rest = rest.dropFirst() }
        guard let separator = rest.first, ".)-–:".contains(separator) else { return nil }

        let body = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        guard let firstChar = body.first, firstChar.isLetter || "«\"'".contains(firstChar) else { return nil }
        return (String(digits), body)
    }
    static func subItem(in line: String) -> String? {
        let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: "#*_- "))
        guard let first = cleaned.first, first.isLowercase, first.isLetter else { return nil }

        let rest = cleaned.dropFirst()
        guard let separator = rest.first, separator == ")" || separator == "." else { return nil }

        let body = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        return body.isEmpty ? nil : body
    }
    static func declaredTotal(in text: String) -> Int? {
        firstCapture(#"punteggio\s+(?:totale|massimo)\s*:?\s*(\d{1,3})"#, in: text).flatMap(Int.init)
    }
    static func isStructural(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return false }
        if "|•▪".contains(first) { return true }
        if first == "-" || first == "*" { return true }
        return trimmed.hasSuffix(" V  F") || trimmed.hasSuffix("V/F")
    }
    static func isMetadata(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("tempo a disposizione")
            || lower.hasPrefix("tempo:")
            || lower.hasPrefix("durata")
            || lower.hasPrefix("tempo ")
            || lower.hasPrefix("punteggio totale")
            || lower.hasPrefix("punteggio massimo")
            || lower.contains("la sufficienza")
            || lower.hasPrefix("valutazione:")
    }
    static func points(in line: String) -> Int? {
        for pattern in [#"\((?:punt[io]\s*)(\d{1,3})\)"#, #"\((\d{1,3})\s*punt[io]\)"#,
                        #"punt[io]\s*:\s*(\d{1,3})"#, #"\[(\d{1,3})\s*p\.?\]"#,
                        #"^\s*punt[io]\s+(\d{1,3})\s*$"#] {
            if let value = firstCapture(pattern, in: line) { return Int(value) }
        }
        return nil
    }
    static func duration(in text: String) -> Int? {
        if let minutes = firstCapture(#"(\d{1,3})\s*minut"#, in: text) { return Int(minutes) }
        if let minutes = firstCapture(#"(\d{1,3})\s*min\b"#, in: text) { return Int(minutes) }
        if let hours = firstCapture(#"(\d)\s*or[ae]\b"#, in: text), let h = Int(hours) { return h * 60 }
        let lower = text.lowercased()
        if lower.contains("un'ora e mezza") || lower.contains("un ora e mezza") { return 90 }
        if lower.contains("due ore e mezza") { return 150 }
        if lower.contains("un'ora") || lower.contains("un ora") { return 60 }
        if lower.contains("due ore") { return 120 }
        return nil
    }

    private static func strippingPoints(_ text: String) -> String {
        var result = text
        for pattern in [#"\s*\((?:punt[io]\s*)\d{1,3}\)"#, #"\s*\(\d{1,3}\s*punt[io]\)"#,
                        #"\s*punt[io]\s*:\s*\d{1,3}"#, #"\s*\[\d{1,3}\s*p\.?\]"#,
                        #"^\s*punt[io]\s+\d{1,3}\s*$"#] {
            result = result.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "* ")).trimmingCharacters(in: .whitespaces)
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
