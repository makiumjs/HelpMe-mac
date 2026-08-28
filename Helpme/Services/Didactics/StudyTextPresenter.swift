import Foundation

/// Prepara il materiale generato per l'area di lettura dello studente.
///
/// Il testo prodotto dall'IA porta con sé i marcatori che servono all'app —
/// `### Domanda 1`, `- [x] Compressione :: esatto, …` — e mostrarlo tale e
/// quale ha due conseguenze: si legge markup invece di italiano, e
/// soprattutto **si legge quale sia la risposta giusta** prima ancora di
/// aprire il quiz. L'autoverifica non verificherebbe più niente.
///
/// Il docente continua a vedere il testo integrale nel proprio editor: è lui
/// che deve poterlo controllare e correggere.
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

            // I cancelletti dei titoli non si leggono ad alta voce.
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

        // Al massimo una riga vuota di seguito: il testo resta arioso senza
        // buchi, che per chi legge con fatica sono un ostacolo in più.
        var compacted: [String] = []
        for line in lines {
            if line.isEmpty && (compacted.last?.isEmpty ?? true) { continue }
            compacted.append(line)
        }
        while compacted.last?.isEmpty == true { compacted.removeLast() }

        return compacted.joined(separator: "\n")
    }

    /// Il materiale come deve finire nel documento Word consegnato allo
    /// studente.
    ///
    /// Differisce da `readable(_:)` in una cosa sola ma decisiva: **conserva
    /// il markdown**. `MarkdownToOoxml` converte `#` in titoli, `- ` in
    /// elenchi puntati e le righe con le barre in tabelle vere — la griglia
    /// di valutazione è una di quelle — quindi appiattire il testo come fa
    /// `readable(_:)` distruggerebbe la formattazione del documento
    /// ufficiale per tutti i formati, non solo per il quiz.
    ///
    /// Quello che toglie è il marcatore della risposta esatta e la
    /// spiegazione per-opzione: senza questo passaggio lo studente si
    /// ritrova le soluzioni stampate sul foglio della verifica.
    public static func handout(_ content: String) -> String {
        guard !content.isEmpty else { return content }

        let lines = content.components(separatedBy: .newlines).map { rawLine -> String in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if let option = DidacticMarkup.quizOption(in: trimmed) {
                // Resta un punto elenco, così Word lo impagina come tale:
                // sparisce solo ciò che rivela la risposta.
                let indent = String(rawLine.prefix(while: { $0 == " " || $0 == "\t" }))
                return indent + option.bullet + option.text
            }

            return readableSeparators(in: rawLine)
        }

        return lines.joined(separator: "\n")
    }

    /// La chiave di correzione, per il docente.
    ///
    /// Restituisce `nil` se il materiale non contiene un quiz: negli altri
    /// formati non c'è nulla da correggere e il documento non deve
    /// guadagnare una pagina vuota.
    ///
    /// Le risposte si citano per testo e non per lettera, perché sul foglio
    /// dello studente le opzioni sono punti elenco senza lettera: dire
    /// "risposta B" costringerebbe a contare.
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

    /// `::` separa concetto e dettaglio nel formato chiesto al modello, ma
    /// letto ad alta voce non è niente e sulla pagina è rumore: diventa una
    /// lineetta, che si legge come la pausa che è.
    private static func readableSeparators(in line: String) -> String {
        var output = line
        for separator in [" :: ", "::"] {
            output = output.replacingOccurrences(of: separator, with: " — ")
        }
        return output
    }

    /// Il testo di un'opzione di quiz, spogliato del marcatore della
    /// risposta esatta **e della spiegazione**: quest'ultima direbbe
    /// "esatto" o "no, invece…" e rivelerebbe comunque la soluzione.
    private static func quizOption(in line: String) -> String? {
        DidacticMarkup.quizOption(in: line)?.text
    }
}
