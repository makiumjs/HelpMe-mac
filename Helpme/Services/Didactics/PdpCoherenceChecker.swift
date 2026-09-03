import Foundation

/// Verifica la coerenza normativa e pedagogica tra la verifica curricolare
/// di partenza e le misure del PDP dell'alunno, in conformità con
/// L. 170/2010 e D.I. 182/2020 (coordinato con D.I. 153/2023).
///
/// Non calcola regole aritmetiche fittizie (già gestite da ExamParser),
/// ma segnala incongruenze sostanziali (durata base mancante con tempo maggiorato,
/// richieste mnemoniche in contrasto con le dispense, strumenti da banco omessi).
public nonisolated enum PdpCoherenceChecker {

    public struct Notice: Identifiable, Equatable, Sendable {
        public enum Severity: String, Sendable {
            case warning = "Attenzione"
            case suggestion = "Suggerimento"
        }

        public let id: String
        public let severity: Severity
        public let title: String
        public let message: String
        public let legalReference: String?

        public init(
            id: String,
            severity: Severity,
            title: String,
            message: String,
            legalReference: String? = nil
        ) {
            self.id = id
            self.severity = severity
            self.title = title
            self.message = message
            self.legalReference = legalReference
        }
    }

    /// Esegue il controllo di coerenza completo tra una verifica analizzata
    /// e le misure PDP registrate per lo studente.
    public static func check(
        exam: ParsedExam,
        studentName: String,
        compensatory: [String],
        dispensatory: [String]
    ) -> [Notice] {
        var notices: [Notice] = []

        let dispMeasures = dispensatory.compactMap { MeasureCatalog.matching($0) }
        let compMeasures = compensatory.compactMap { MeasureCatalog.matching($0) }
        let dispIds = Set(dispMeasures.map(\.id))
        let compIds = Set(compMeasures.map(\.id))

        let fullExamText = (exam.sections.compactMap(\.title) + exam.questions.map(\.text) + exam.questions.flatMap(\.subItems))
            .joined(separator: "\n")
            .lowercased()

        // 1. Tempi aggiuntivi (disp.tempi): verifica senza durata
        if dispIds.contains("disp.tempi") || hasPartialMatch(dispensatory, keywords: ["tempo", "tempi", "30%"]) {
            if exam.durationMinutes == nil {
                notices.append(Notice(
                    id: "pdp.missing-duration",
                    severity: .warning,
                    title: "Durata base della classe non indicata",
                    message: "Per \(studentName) è previsto il tempo aggiuntivo (+30%), ma la verifica della classe non riporta la durata base. Indica i minuti nell'editor (es. «Durata: 60 minuti») per consentire il calcolo automatico del tempo equipollente.",
                    legalReference: "L. 170/2010 — Linee Guida D.M. 5669/2011"
                ))
            }
        }

        // 2. Strumenti compensativi da banco (comp.formulari, comp.calcolatrice, comp.tavola-pitagorica, ecc.)
        let usableToolsInPdp = compIds.intersection(MeasureCatalog.usableDuringTest)
        let examHasCalculationsOrFormulas = hasMathOrFormulas(in: fullExamText)

        if usableToolsInPdp.isEmpty && examHasCalculationsOrFormulas {
            notices.append(Notice(
                id: "pdp.no-compensatory-tools",
                severity: .suggestion,
                title: "Nessuno strumento da banco nel PDP",
                message: "La verifica contiene calcoli o formule, ma nella scheda di \(studentName) non sono selezionati strumenti compensativi da banco (es. formulario, tavola pitagorica o calcolatrice). Se previsti nel suo PDP, aggiungili nella scheda misure.",
                legalReference: "L. 170/2010 art. 5 comma 2"
            ))
        }

        // 3. Dispensa dallo studio mnemonico (disp.memorizzazione) vs richieste mnemoniche
        if dispIds.contains("disp.memorizzazione") || hasPartialMatch(dispensatory, keywords: ["mnemonico", "memoria", "formule"]) {
            let mnemonicPatterns = [
                "a memoria",
                "a mente",
                "calcola a mente",
                "senza consultare",
                "senza formulario",
                "senza tabelle",
                "senza calcolatrice",
                "senza appunti"
            ]
            if let matched = mnemonicPatterns.first(where: { containsWordSequence(fullExamText, sequence: $0) }) {
                notices.append(Notice(
                    id: "pdp.conflict.mnemonic",
                    severity: .warning,
                    title: "Richiesta mnemonica in contrasto col PDP",
                    message: "Il testo della prova include la richiesta «\(matched)», in contrasto con la misura dispensativa dallo studio mnemonico di formule, tabelle e definizioni prevista per \(studentName).",
                    legalReference: "D.M. 5669/2011 art. 4"
                ))
            }
        }

        // 4. Dispensa dalla lettura ad alta voce (disp.lettura-alta-voce)
        if dispIds.contains("disp.lettura-alta-voce") || hasPartialMatch(dispensatory, keywords: ["alta voce", "voce alta"]) {
            let readingPatterns = [
                "leggi ad alta voce",
                "leggi a voce alta",
                "leggi alla classe",
                "leggere ad alta voce",
                "lettura ad alta voce"
            ]
            if let matched = readingPatterns.first(where: { containsWordSequence(fullExamText, sequence: $0) }) {
                notices.append(Notice(
                    id: "pdp.conflict.reading-aloud",
                    severity: .warning,
                    title: "Richiesta di lettura ad alta voce in contrasto col PDP",
                    message: "Il testo della prova richiede «\(matched)», ma per \(studentName) è attiva la dispensa dalla lettura ad alta voce.",
                    legalReference: "L. 170/2010 art. 5 comma 2"
                ))
            }
        }

        // 5. Dispensa dalla scrittura sotto dettatura (disp.dettatura)
        if dispIds.contains("disp.dettatura") || hasPartialMatch(dispensatory, keywords: ["dettatura", "dettato"]) {
            let dictationPatterns = [
                "sotto dettatura",
                "scrivi sotto dettatura",
                "scrivi il dettato"
            ]
            if let matched = dictationPatterns.first(where: { containsWordSequence(fullExamText, sequence: $0) }) {
                notices.append(Notice(
                    id: "pdp.conflict.dictation",
                    severity: .warning,
                    title: "Scrittura sotto dettatura in contrasto col PDP",
                    message: "La prova richiede la scrittura sotto dettatura («\(matched)»), da cui l'alunno è dispensato.",
                    legalReference: "L. 170/2010 art. 5 comma 2"
                ))
            }
        }

        // 6. Riduzione quantitativa degli esercizi (disp.quantita) con troppi quesiti
        if dispIds.contains("disp.quantita") || hasPartialMatch(dispensatory, keywords: ["riduzione quantitativa", "quantitativa"]) {
            let subItemCount = exam.questions.reduce(0) { $0 + $1.subItems.count }
            let totalTasks = exam.questions.count + subItemCount
            if totalTasks >= 8 {
                notices.append(Notice(
                    id: "pdp.high-exercise-count",
                    severity: .suggestion,
                    title: "Carico di quesiti elevato (\(totalTasks) compiti)",
                    message: "Per \(studentName) è prevista la riduzione quantitativa degli esercizi. La prova contiene \(exam.questions.count) quesiti e \(subItemCount) sotto-quesiti: valuta di ridurre il numero di esercizi o indicare quali quesiti sono obbligatori e quali facoltativi.",
                    legalReference: "D.I. 182/2020 coordinato con D.I. 153/2023"
                ))
            }
        }

        return notices
    }

    // MARK: - Rilevamento euristico ausiliario

    private static func hasPartialMatch(_ list: [String], keywords: [String]) -> Bool {
        let normalizedList = list.map { $0.lowercased() }
        return keywords.contains { kw in
            normalizedList.contains { $0.contains(kw) }
        }
    }

    private static func hasMathOrFormulas(in text: String) -> Bool {
        let mathKeywords = [
            "calcola", "risolvi", "equazione", "frazione",
            "percentuale", "formula", "teorema", "geometria",
            "massa", "volume", "densità", "velocità", "accelerazione",
            "area", "perimetro", "km/h", "km/s", "m/s", "cm²", "m²", "kg"
        ]
        return mathKeywords.contains { containsWordSequence(text, sequence: $0) }
    }

    private static func containsWordSequence(_ text: String, sequence: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: "\\b" + NSRegularExpression.escapedPattern(for: sequence) + "\\b",
            options: [.caseInsensitive]
        ) else {
            return text.contains(sequence)
        }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
