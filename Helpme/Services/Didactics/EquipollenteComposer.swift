import Foundation

/// Costruisce la verifica equipollente dalla verifica della classe.
///
/// Non riscrive i contenuti: quelli sono già quelli giusti, li ha scelti il
/// docente curricolare per la sua classe, e l'equipollenza sta nel mantenere
/// gli stessi obiettivi (D.I. 182/2020 Art. 15). Quello che l'app fa è il
/// lavoro di segreteria che ruba il pomeriggio: rinumerare, togliere i
/// punteggi dal testo dei quesiti e portarli in griglia, calcolare il tempo
/// maggiorato, elencare gli strumenti concessi, lasciare lo spazio per
/// scrivere.
///
/// Quello che non fa è scomporre una domanda aperta in micro-step guidati.
/// Quella è la parte che richiede di conoscere l'alunno, e resta al docente
/// di sostegno: il documento esce nell'editor, dove si completa.
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

    /// Tempo maggiorato del 30% (Linee guida 4.4), arrotondato ai 5 minuti:
    /// nessuno consegna un compito dopo settantotto minuti esatti.
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

    /// Cosa l'alunno può tenere sul banco. Sta sul suo foglio perché è una
    /// cosa che deve sapere lui, non solo chi sorveglia.
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
                    block += "\n\n" + question.subItems.enumerated()
                        .map { "   \(letter(for: $0.offset))) \($0.element)" }
                        .joined(separator: "\n\n" + answerSpace(lines: 2) + "\n\n")
                }
                let lines = writingLines(for: question)
                if lines > 0 { block += "\n\n" + answerSpace(lines: lines) }
                blocks.append(block)
            }
        }
        return blocks
    }

    /// Lo spazio per rispondere cresce con il punteggio: un quesito da cinque
    /// punti chiede più righe di uno da due. Chi scrive a fatica ha bisogno
    /// di righe grandi, non di margini stretti.
    private static func writingLines(for question: ExamQuestion) -> Int {
        // Un completamento, un vero/falso o una tabella da riempire si
        // rispondono dentro il quesito: le righe sotto sono spazio sprecato,
        // e su un foglio che deve restare corto contano.
        if answersInPlace(question) { return 0 }
        guard let points = question.points else { return 4 }
        // Righe generose ma non sprecate: chi scrive a fatica ha bisogno di
        // spazio, ma un compito di sei pagine si affronta peggio di uno di due.
        return min(8, max(3, points + 1))
    }

    /// Una tabella markdown o un elenco vogliono una riga vuota davanti,
    /// altrimenti restano attaccati alla frase e non si formattano.
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

    /// Vero quando la risposta si scrive dentro il testo del quesito.
    static func answersInPlace(_ question: ExamQuestion) -> Bool {
        let text = question.text
        return text.contains("______")            // completamento
            || text.contains("\n|")               // tabella da riempire
            || text.contains(" V  F")             // vero/falso
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

    /// La griglia è obbligatoria (D.I. 182/2020) e qui si costruisce dai
    /// punteggi che il docente curricolare aveva già assegnato: l'equipollenza
    /// sta anche nel non cambiare il peso dei quesiti.
    private static func grid(for exam: ParsedExam) -> String {
        var rows = ["| Quesito | Indicatore | Punti previsti | Punti assegnati |",
                    "|---|---|---|---|"]

        for question in exam.questions {
            let points = question.points.map(String.init) ?? ""
            rows.append("| \(question.number) | \(indicator(for: question)) | \(points) | |")
        }

        var grid = "### Griglia di valutazione — Consiglio di Classe\n\n"
        if let total = exam.totalPoints {
            rows.append("| | **Totale** | **\(total)** | |")
        }
        grid += rows.joined(separator: "\n")

        // Meglio una colonna vuota che dei punteggi inventati: quanto pesa un
        // quesito lo decide chi ha costruito la prova.
        if exam.totalPoints == nil {
            grid += "\n\n*La prova della classe non assegnava punteggi ai singoli quesiti: "
                 + "la colonna dei punti previsti è da compilare.*"
        } else if let declared = exam.declaredTotalPoints {
            let recognised = exam.questions.compactMap(\.points).reduce(0, +)
            if recognised < declared {
                grid += "\n\n*Dei \(declared) punti dichiarati dalla prova ne ho riconosciuti \(recognised): "
                     + "le caselle vuote sono quesiti a cui il testo di partenza non assegnava un punteggio.*"
            }
        }
        return grid
    }

    /// Un indicatore di partenza, dedotto da come è formulato il quesito.
    ///
    /// Il docente lo corregge: è un punto da cui partire, non una valutazione
    /// automatica. Ma quattordici righe che dicono tutte "Conoscenza dei
    /// contenuti" non fanno risparmiare niente a nessuno.
    static func indicator(for question: ExamQuestion) -> String {
        let text = question.text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"«»' "))

        // I problemi con sotto-punti sono applicativi comunque siano scritti.
        if !question.subItems.isEmpty { return "Applicazione: imposta e svolge il procedimento" }

        for (openers, indicator) in indicatorRules where openers.contains(where: { text.hasPrefix($0) }) {
            return indicator
        }
        if text.contains("calcola") { return "Applicazione: imposta e svolge il procedimento" }

        // L'interrogativo non sta sempre in testa: "La rinnovata circolazione
        // della moneta che cosa permetteva al re?" chiede la stessa cosa di
        // "Che cosa permetteva al re la rinnovata circolazione della moneta?".
        for (openers, indicator) in indicatorRules where openers.contains(where: { text.contains($0) }) {
            return indicator
        }
        return "Conoscenza dei contenuti"
    }

    /// Le forme in cui i docenti scrivono davvero i quesiti: consegne
    /// all'imperativo e domande dirette.
    private static let indicatorRules: [(openers: [String], indicator: String)] = [
        (["perche"], "Comprensione: spiega le cause"),
        // Con e senza apostrofo: "Com'era organizzato il territorio?" e'
        // la forma piu' comune in cui una domanda del genere viene scritta.
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


private extension String {
    /// "VERIFICA DI MECCANICA AGRARIA" → "Verifica di meccanica agraria".
    /// Il maiuscolo integrale e' faticoso da leggere per chiunque, e per un
    /// alunno con dislessia toglie proprio gli appigli che usa: il profilo
    /// della parola.
    var capitalizedFirstOnly: String {
        let letters = filter(\.isLetter)
        guard !letters.isEmpty, letters.allSatisfy(\.isUppercase) else { return self }
        let lowered = lowercased()
        return lowered.prefix(1).uppercased() + lowered.dropFirst()
    }
}
