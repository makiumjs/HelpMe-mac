import Foundation

public nonisolated struct QuizOption: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public var text: String
    public var isCorrect: Bool
    /// Spiegazione formativa: perché questa risposta è giusta o sbagliata.
    public var explanation: String?

    public init(text: String, isCorrect: Bool, explanation: String? = nil) {
        self.text = text
        self.isCorrect = isCorrect
        self.explanation = explanation
    }
}

public nonisolated struct QuizQuestion: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public var prompt: String
    public var options: [QuizOption]

    public init(prompt: String, options: [QuizOption]) {
        self.prompt = prompt
        self.options = options
    }

    /// Una domanda è utilizzabile solo se ha esattamente una risposta giusta
    /// e almeno due alternative: altrimenti non c'è niente da scegliere.
    public var isUsable: Bool {
        options.count >= 2 && options.filter(\.isCorrect).count == 1
    }

    public var correctOption: QuizOption? {
        options.first(where: \.isCorrect)
    }
}

/// Ricostruisce un quiz cliccabile dal testo generato dall'IA.
///
/// Il formato chiesto nel prompt è la casella `- [x]`, ma i modelli
/// derivano facilmente verso "A) … ✅" o "Risposta corretta: B":
/// il parser accetta anche quelli, perché una domanda persa in silenzio
/// è peggio di una domanda formattata male.
public nonisolated enum QuizParser {

    public static func parse(_ text: String) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        var prompt: String? = nil
        var options: [QuizOption] = []
        var letters: [String: Int] = [:]

        func flush() {
            if let prompt, !prompt.isEmpty, !options.isEmpty {
                let question = QuizQuestion(prompt: prompt, options: options)
                if question.isUsable { questions.append(question) }
            }
            prompt = nil
            options = []
            letters = [:]
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // "Risposta corretta: B" — indica a posteriori quale opzione vale.
            if let letter = correctAnswerLetter(in: line) {
                if let index = letters[letter] {
                    for position in options.indices { options[position].isCorrect = false }
                    options[index].isCorrect = true
                }
                continue
            }

            if let (letter, option) = parseOption(line) {
                if let letter { letters[letter] = options.count }
                options.append(option)
                continue
            }

            if isQuestionMarker(line) {
                flush()
                prompt = cleanPrompt(line)
                continue
            }

            if options.isEmpty {
                let cleaned = MindmapParser.stripEmphasis(line)
                if let existing = prompt, !existing.isEmpty {
                    // Righe successive di una domanda spezzata su più righe.
                    if !existing.hasSuffix("?") { prompt = existing + " " + cleaned }
                } else {
                    // Nessun testo ancora: qui sta la domanda vera, per
                    // esempio la riga sotto un titolo "### Domanda 1".
                    prompt = cleaned
                }
            } else if let explanation = trailingExplanation(line) {
                // Spiegazione unica riferita alla risposta giusta.
                if let index = options.firstIndex(where: { $0.isCorrect }), options[index].explanation == nil {
                    options[index].explanation = explanation
                }
            }
        }

        flush()
        return questions
    }

    // MARK: - Righe di opzione

    private static let correctnessMarkers = [
        "✅", "✔️", "✔", "☑️", "☑", "(corretta)", "(corretto)", "(giusta)", "(giusto)",
        "(risposta corretta)", "[corretta]", "[x]", "[X]", "← corretta", "→ corretta",
        "- corretta", "risposta corretta"
    ]

    /// Riconosce `- [x] testo`, `A) testo`, `* testo`.
    /// Restituisce la lettera dell'opzione, se c'è, e l'opzione stessa.
    static func parseOption(_ line: String) -> (letter: String?, option: QuizOption)? {
        var body = line
        var isCorrect = false
        var letter: String? = nil

        // 1. Casella di spunta, con o senza trattino davanti.
        for bullet in ["- ", "* ", "+ ", ""] where body.hasPrefix(bullet) {
            let rest = String(body.dropFirst(bullet.count))
            let lowered = rest.lowercased()
            if lowered.hasPrefix("[x]") || lowered.hasPrefix("[ ]") {
                isCorrect = lowered.hasPrefix("[x]")
                body = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let (text, explanation) = splitExplanation(body)
                guard !text.isEmpty else { return nil }
                return (nil, QuizOption(text: text, isCorrect: isCorrect, explanation: explanation))
            }
            if !bullet.isEmpty { break }
        }

        // 2. Lettera: "A) testo", "- b. testo".
        var candidate = body
        for bullet in ["- ", "* ", "+ "] where candidate.hasPrefix(bullet) {
            candidate = String(candidate.dropFirst(bullet.count))
            break
        }

        let characters = Array(candidate)
        guard characters.count >= 3,
              let first = characters.first,
              first.isLetter,
              first.isASCII,
              characters[1] == ")" || characters[1] == "." || characters[1] == ":",
              characters[2] == " " else {
            return nil
        }

        letter = String(first).uppercased()
        body = String(candidate.dropFirst(3)).trimmingCharacters(in: .whitespaces)

        let lowered = body.lowercased()
        for marker in correctnessMarkers where lowered.contains(marker.lowercased()) {
            isCorrect = true
            break
        }

        let stripped = stripCorrectnessMarkers(body)
        let (text, explanation) = splitExplanation(stripped)
        guard !text.isEmpty else { return nil }

        return (letter, QuizOption(text: text, isCorrect: isCorrect, explanation: explanation))
    }

    private static func stripCorrectnessMarkers(_ text: String) -> String {
        var output = text
        for marker in correctnessMarkers {
            output = output.replacingOccurrences(of: marker, with: "", options: .caseInsensitive)
        }
        return output.trimmingCharacters(in: CharacterSet(charactersIn: " \t-–—:")).trimmingCharacters(in: .whitespaces)
    }

    /// Separa "opzione :: spiegazione".
    private static func splitExplanation(_ text: String) -> (String, String?) {
        for separator in [" :: ", "::", " — ", " – ", " | "] {
            if let range = text.range(of: separator) {
                let option = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let explanation = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !option.isEmpty && !explanation.isEmpty {
                    return (MindmapParser.stripEmphasis(option), MindmapParser.stripEmphasis(explanation))
                }
            }
        }
        return (MindmapParser.stripEmphasis(text), nil)
    }

    // MARK: - Righe di domanda

    private static func isQuestionMarker(_ line: String) -> Bool {
        let lowered = MindmapParser.stripEmphasis(line).lowercased()

        if line.hasPrefix("#") { return true }
        if lowered.hasPrefix("domanda") { return true }

        // "3. Qual è …?" — un numero seguito da testo che chiede qualcosa.
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty {
            let rest = line.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") { return true }
        }

        return false
    }

    private static func cleanPrompt(_ line: String) -> String {
        var text = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)

        let digits = text.prefix { $0.isNumber }
        if !digits.isEmpty {
            let rest = text.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                text = String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }

        text = MindmapParser.stripEmphasis(text)

        // Un titolo "### Domanda 1" è solo un'etichetta: la domanda vera sta
        // nella riga sotto. Restituire vuoto le lascia il posto, invece di
        // ritrovarsi "Domanda 1 Quante fasi ci sono?".
        if isBareQuestionLabel(text) { return "" }

        // "Domanda 3: Qual è …" → "Qual è …"
        if text.lowercased().hasPrefix("domanda") {
            if let colon = text.firstIndex(of: ":") {
                let remainder = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if !remainder.isEmpty { return remainder }
            }
            let withoutWord = text.dropFirst("domanda".count).trimmingCharacters(in: .whitespaces)
            let withoutNumber = withoutWord.drop { $0.isNumber || $0 == "." || $0 == ")" || $0 == " " }
            let candidate = String(withoutNumber).trimmingCharacters(in: .whitespaces)
            if !candidate.isEmpty { return candidate }
        }

        return text
    }

    /// Vero per "Domanda", "Domanda 3", "Domanda 3:" — cioè per una riga
    /// che annuncia la domanda senza contenerla.
    static func isBareQuestionLabel(_ text: String) -> Bool {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard lowered.hasPrefix("domanda") else { return false }
        let remainder = lowered.dropFirst("domanda".count)
            .trimmingCharacters(in: CharacterSet(charactersIn: " 0123456789:.)-–—"))
        return remainder.isEmpty
    }

    /// "Risposta corretta: B" → "B".
    private static func correctAnswerLetter(in line: String) -> String? {
        let lowered = MindmapParser.stripEmphasis(line).lowercased()
        for prefix in ["risposta corretta", "risposta esatta", "soluzione"] where lowered.hasPrefix(prefix) {
            let remainder = lowered.dropFirst(prefix.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: " :=—–-"))
            guard let first = remainder.first, first.isLetter, first.isASCII else { return nil }
            // Solo se è davvero una lettera isolata, non l'inizio di una frase.
            let second = remainder.dropFirst().first
            guard second == nil || second == ")" || second == "." || second == " " else { return nil }
            return String(first).uppercased()
        }
        return nil
    }

    private static func trailingExplanation(_ line: String) -> String? {
        let cleaned = MindmapParser.stripEmphasis(line)
        let lowered = cleaned.lowercased()
        for prefix in ["spiegazione", "perché", "perche", "motivazione", "nota"] where lowered.hasPrefix(prefix) {
            let remainder = cleaned.dropFirst(prefix.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: " :=—–-"))
            return remainder.isEmpty ? nil : remainder
        }
        return nil
    }
}
