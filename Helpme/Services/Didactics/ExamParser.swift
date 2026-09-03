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
        guard let first = sections.first, let heading = first.title else { return nil }
        if first.questions.isEmpty { return heading }
        return sections.count == 1 && ExamParser.looksLikeExamTitle(heading) ? heading : nil
    }
    public var contentSections: [ExamSection] {
        var sections = self.sections.filter { !$0.questions.isEmpty }
        if title != nil, !sections.isEmpty, sections[0].title == self.sections.first?.title {
            sections[0].title = nil
        }
        return sections
    }
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
            // Una consegna all'imperativo o una domanda diretta apre un quesito
            // anche senza numero. Finche' la ricaduta senza numerazione era
            // tutto-o-niente, bastava un solo quesito numerato in mezzo a una
            // verifica scritta all'imperativo per perdere tutti gli altri.
            // Una consegna all'imperativo o una domanda diretta apre un quesito
            // anche senza numero — ma solo se quello in corso e' gia' una frase
            // finita: un quesito spezzato a meta' frase continua, e la sua
            // seconda riga finisce spesso con il punto interrogativo.
            if (isAssignment(line) || line.hasSuffix("?")), completesTheQuestion(pending?.text) {
                closeQuestion()
                pending = ExamQuestion(number: "",
                                       text: strippingPoints(line.trimmingCharacters(
                                           in: CharacterSet(charactersIn: "#*_-• \t"))),
                                       points: points(in: line))
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

        var parsed = renumbered(ParsedExam(sections: sections, durationMinutes: duration(in: text)))
        parsed.declaredTotalPoints = declaredTotal(in: text)
        return parsed.isEmpty ? parseUnnumberedQuestions(text) : parsed
    }
    /// La verifica equipollente e' un documento nuovo e la sua numerazione
    /// dev'essere sua: una prova che mescola quesiti numerati e consegne
    /// all'imperativo produrrebbe altrimenti numeri che si scontrano.
    static func renumbered(_ exam: ParsedExam) -> ParsedExam {
        var result = exam
        var next = 1
        for sectionIndex in result.sections.indices {
            for questionIndex in result.sections[sectionIndex].questions.indices {
                result.sections[sectionIndex].questions[questionIndex].number = String(next)
                next += 1
            }
        }
        return result
    }

    static func parseUnnumberedQuestions(_ text: String) -> ParsedExam {
        var section = ExamSection()
        var title: String?
        var number = 1

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "#*_-• \t"))
            guard !line.isEmpty, !isMetadata(line) else { continue }

            if line.hasSuffix("?") || isAssignment(line) {
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
        var parsed = renumbered(ParsedExam(sections: sections, durationMinutes: duration(in: text)))
        parsed.declaredTotalPoints = declaredTotal(in: text)
        return parsed
    }

    // MARK: - Riconoscitori
    static func looksLikeExamTitle(_ heading: String) -> Bool {
        let lower = heading.lowercased()
        return ["verifica", "prova", "compito", "test", "esame"].contains { lower.hasPrefix($0) }
    }

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
        if let second = rest.dropFirst().first, rest.first == " ", "-–—".contains(second) {
            rest = rest.dropFirst()
        }
        guard let separator = rest.first, ".)-–—:".contains(separator) else { return nil }

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
        return isTrueFalseMarker(trimmed)
    }
    /// Lista chiusa apposta: riconoscere l'imperativo dalla desinenza
    /// prenderebbe dentro mezza terza persona dell'indicativo — "la crosta
    /// *copre* il mantello" — e ogni frase di un brano diventerebbe un quesito.
    /// Fuori "verifica" e "controlla", che sono anche intestazioni.
    private static let assignmentOpeners = [
        "descrivi", "elenca", "spiega", "calcola", "illustra", "definisci",
        "indica", "completa", "individua", "confronta", "analizza", "argomenta",
        "motiva", "riassumi", "classifica", "determina", "risolvi", "converti",
        "scrivi", "esponi", "commenta", "distingui", "collega", "ordina",
        "traduci", "disegna", "rappresenta", "svolgi", "giustifica"
    ]

    /// Vero quando il quesito in corso e' gia' chiuso, o non ce n'e' nessuno.
    static func completesTheQuestion(_ text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return true }
        return ".?!:".contains(text.last ?? " ")
    }

    static func isAssignment(_ line: String) -> Bool {
        let lower = line
            .trimmingCharacters(in: CharacterSet(charactersIn: "#*_-• \t"))
            .lowercased()
        guard let first = lower.split(separator: " ").first else { return false }
        return assignmentOpeners.contains(String(first))
    }

    static func isTrueFalseMarker(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.hasSuffix(" v  f") || lower.hasSuffix("v/f")
            || lower.hasSuffix(" v o f") || lower.hasSuffix(" v o f.")
            || lower.hasSuffix(" vero o falso") || lower.hasSuffix(" vero/falso")
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
            || lower.hasPrefix("leggi ")
            || lower.hasPrefix("osserva la figura")
            || lower.hasPrefix("osserva l'immagine")
    }
    static func points(in line: String) -> Int? {
        for pattern in [#"\((?:punt[io]\s*)(\d{1,3})\)"#, #"\((\d{1,3})\s*punt[io]\)"#,
                        #"punt[io]\s*:\s*(\d{1,3})"#, #"\[(\d{1,3})\s*p\.?\]"#,
                        #"^\s*punt[io]\s+(\d{1,3})\s*$"#,
                        #"punt[io]\s+(\d{1,3})\s*$"#,
                        // Almeno due trattini o puntini prima della barra, o in una
                        // verifica di matematica "Calcola 6/2" perde il divisore.
                        #"[_.]{2,}\s*/\s*(\d{1,3})"#] {
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
                        #"\s*punt[io]\s+\d{1,3}\s*$"#] {
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
