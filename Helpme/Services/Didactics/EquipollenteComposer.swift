import Foundation

public nonisolated enum EquipollenteComposer {

    public struct Input: Sendable {
        public let studentName: String
        public let classInfo: String
        public let programTitle: String
        public let compensatory: [String]
        public let dispensatory: [String]
        public let exam: ParsedExam
        public init(
            studentName: String, classInfo: String, programTitle: String,
            compensatory: [String], dispensatory: [String], exam: ParsedExam
        ) {
            self.studentName = studentName
            self.classInfo = classInfo
            self.programTitle = programTitle
            self.compensatory = compensatory
            self.dispensatory = dispensatory
            self.exam = exam
        }
    }
    public static func extendedMinutes(from original: Int) -> Int {
        let extended = Double(original) * 1.3
        return Int((extended / 5).rounded(.up)) * 5
    }

    public static func compose(_ input: Input) -> String {
        var parts: [String] = []

        var heading = "## Verifica equipollente"
        if let title = input.exam.title { heading += " — \(title.capitalizedFirstOnly)" }
        parts.append("""
        \(heading)

        **Alunno:** \(input.studentName) — **Classe:** \(input.classInfo)
        **Percorso:** \(input.programTitle)
        """)

        if let original = input.exam.durationMinutes {
            let extended = extendedMinutes(from: original)
            parts.append("""
            **Tempo a disposizione: \(extended) minuti** \
            (\(original) minuti della prova della classe, più il 30% previsto dalle misure compensative).
            """)
        } else {
            parts.append("""
            **Tempo a disposizione:** _____ minuti \
            (la prova della classe non indicava una durata: scrivila qui, maggiorata del 30%).
            """)
        }

        if let tools = allowedTools(input.compensatory) {
            parts.append(tools)
        }

        parts.append(contentsOf: questionBlocks(input.exam))
        parts.append(grid(for: input.exam))
        parts.append(teacherFooter(input))

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Le parti
    private static func allowedTools(_ compensatory: [String]) -> String? {
        let tools = compensatory
            .compactMap { MeasureCatalog.matching($0) }
            .filter { MeasureCatalog.usableDuringTest.contains($0.id) }
            .map(\.text)

        guard !tools.isEmpty else { return nil }
        return "### Puoi usare durante la prova\n\n" + tools.map { "- \($0)" }.joined(separator: "\n")
    }

    private static func questionBlocks(_ exam: ParsedExam) -> [String] {
        var blocks: [String] = []

        for section in exam.contentSections {
            if let title = section.title { blocks.append("### \(title)") }

            for question in section.questions {
                var block = "**\(question.number).** " + spacedBeforeBlocks(question.text)

                if !question.subItems.isEmpty {
                    for (index, sub) in question.subItems.enumerated() {
                        block += "\n\n   \(letter(for: index))) \(sub)"
                        block += "\n\n" + (guidedSteps(for: sub).map { $0.joined(separator: "\n\n") }
                                            ?? answerSpace(lines: 3))
                    }
                    blocks.append(block)
                    continue
                }

                if let steps = guidedSteps(for: question.text) {
                    block += "\n\n" + steps.joined(separator: "\n\n")
                } else {
                    let lines = writingLines(for: question)
                    if lines > 0 { block += "\n\n" + answerSpace(lines: lines) }
                }
                blocks.append(block)
            }
        }
        return blocks
    }
    private static func writingLines(for question: ExamQuestion) -> Int {
        if answersInPlace(question) { return 0 }
        guard let points = question.points else { return 4 }
        return min(8, max(3, points + 1))
    }

    static func spacedBeforeBlocks(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard lines.count > 1 else { return text }

        var result = [lines[0]]
        var opened = false
        for line in lines.dropFirst() {
            let isBlock = line.hasPrefix("|") || line.hasPrefix("•") || line.hasPrefix("- ")
            if isBlock && !opened { result.append("") }
            opened = isBlock
            result.append(line)
        }
        return result.joined(separator: "\n")
    }
    static func guidedSteps(for text: String) -> [String]? {
        let lower = text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                 locale: Locale(identifier: "it_IT"))

        if ["calcola", "determina", "converti", "risolvi"].contains(where: { lower.hasPrefix($0) }) {
            return [
                "Dati che hai: ______________________________________",
                "Formula che userai: _________________________________",
                "Sostituisci i dati e calcola:",
                "",
                "Risultato, con l'unità di misura: ____________________"
            ]
        }

        if let count = requestedCount(in: lower), count >= 2, count <= 6 {
            return (1...count).map { "\($0). _________________________________________" }
        }
        return nil
    }

    static func requestedCount(in text: String) -> Int? {
        let words = ["due": 2, "tre": 3, "quattro": 4, "cinque": 5, "sei": 6]
        guard ["elenca", "indica", "individua", "scrivi", "cita", "nomina"]
            .contains(where: { text.hasPrefix($0) }) else { return nil }

        for token in text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            if let value = words[String(token)] { return value }
            if let digit = Int(token), (2...6).contains(digit) { return digit }
        }
        return nil
    }

    static func answersInPlace(_ question: ExamQuestion) -> Bool {
        let text = question.text
        return text.contains("______")
            || text.contains("\n|")
            || text.contains(" V  F")
            || text.localizedCaseInsensitiveContains("vere o false")
    }

    private static func answerSpace(lines: Int) -> String {
        Array(repeating: "_______________________________________________", count: lines)
            .joined(separator: "\n\n")
    }

    private static func letter(for index: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        return index < alphabet.count ? String(alphabet[index]) : "\(index + 1)"
    }

    static func pointsByQuestion(_ exam: ParsedExam) -> (points: [String: Int], proposed: Set<String>) {
        var points: [String: Int] = [:]
        for question in exam.questions where question.points != nil {
            points[question.number] = question.points
        }

        let uncovered = exam.questions.filter { $0.points == nil }.map(\.number)
        guard !uncovered.isEmpty else { return (points, []) }

        let known = points.values.reduce(0, +)
        let share: Int
        var remainder = 0

        if let declared = exam.declaredTotalPoints, declared > known {
            let residue = declared - known
            share = residue / uncovered.count
            remainder = residue % uncovered.count
        } else if !points.isEmpty {
            share = max(1, Int((Double(known) / Double(points.count)).rounded()))
        } else {
            share = 1
        }

        for (index, number) in uncovered.enumerated() {
            points[number] = max(1, share + (index < remainder ? 1 : 0))
        }
        return (points, Set(uncovered))
    }

    private static func grid(for exam: ParsedExam) -> String {
        var rows = ["| Quesito | Indicatore | Punti previsti | Punti assegnati |",
                    "|---|---|---|---|"]

        let (points, proposed) = pointsByQuestion(exam)
        for question in exam.questions {
            let value = points[question.number].map(String.init) ?? ""
            let cell = proposed.contains(question.number) ? "*\(value)*" : value
            rows.append("| \(question.number) | \(indicator(for: question)) | \(cell) | |")
        }

        let total = points.values.reduce(0, +)
        if total > 0 { rows.append("| | **Totale** | **\(total)** | |") }

        var grid = "### Griglia di valutazione — Consiglio di Classe\n\n" + rows.joined(separator: "\n")

        if !proposed.isEmpty {
            let quali = proposed.sorted { ($0 as NSString).intValue < ($1 as NSString).intValue }.joined(separator: ", ")
            grid += "\n\n*I punteggi in corsivo — quesiti \(quali) — non erano indicati nella prova della classe: "
                 + "sono una proposta in parti uguali, da confermare.*"
        }
        return grid
    }

    static func indicator(for question: ExamQuestion) -> String {
        let text = question.text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"«»' "))

        if !question.subItems.isEmpty { return "Applicazione: imposta e svolge il procedimento" }

        for (openers, indicator) in indicatorRules where openers.contains(where: { text.hasPrefix($0) }) {
            return indicator
        }
        if text.contains("calcola") { return "Applicazione: imposta e svolge il procedimento" }

        for (openers, indicator) in indicatorRules where openers.contains(where: { text.contains($0) }) {
            return indicator
        }
        return "Conoscenza dei contenuti"
    }

    private static let indicatorRules: [(openers: [String], indicator: String)] = [
        (["perche"], "Comprensione: spiega le cause"),
        (["come ", "com'era", "com'e", "concretamente, come", "in che modo"],
         "Comprensione: descrive il procedimento"),
        (["calcola", "determina", "converti", "risolvi"], "Applicazione: imposta e svolge il procedimento"),
        (["completa", "inserisci il termine"], "Completamento: inserisce i termini mancanti"),
        (["indica se", "vero o falso", "vere o false"], "Riconoscimento: distingue vero e falso"),
        (["osserva", "leggi la carta", "completa la tabella"], "Applicazione: legge i dati e li colloca"),
        (["argomenta", "discuti", "commenta", "sostieni"], "Argomentazione: motiva la propria posizione"),
        (["definisci", "che cosa s'intende", "che cosa si intende", "cosa s'intende",
          "che cos'e", "che cose"],
         "Lessico: usa i termini tecnici in modo appropriato"),
        (["quale e la differenza", "qual e la differenza", "qual'e la differenza"],
         "Conoscenza: distingue e confronta"),
        (["chi "], "Conoscenza: individua i soggetti"),
        (["quali ", "elenca"], "Conoscenza: individua ed elenca"),
        (["descrivi", "illustra", "spiega", "esponi"], "Conoscenza: espone i contenuti richiesti"),
        (["qual e", "qual'e", "quale e", "che cosa", "cosa "], "Conoscenza: definisce")
    ]

    private static func teacherFooter(_ input: Input) -> String {
        let measures = (input.compensatory + input.dispensatory)
            .compactMap { MeasureCatalog.matching($0)?.text }
        guard !measures.isEmpty else { return "" }

        return """
        ---

        *Misure applicate a questa prova, per il Consiglio di Classe:*
        \(measures.map { "*— \($0)*" }.joined(separator: "\n"))
        """
    }
}


nonisolated private extension String {
    var capitalizedFirstOnly: String {
        let letters = filter(\.isLetter)
        guard !letters.isEmpty, letters.allSatisfy(\.isUppercase) else { return self }
        let lowered = lowercased()
        return lowered.prefix(1).uppercased() + lowered.dropFirst()
    }
}
