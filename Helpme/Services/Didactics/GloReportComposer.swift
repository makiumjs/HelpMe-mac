import Foundation

/// Compone la relazione di verifica e monitoraggio periodico o finale
/// sull'efficacia delle misure compensative e dispensative,
/// in conformità con il D.I. 182/2020 (coordinato con D.I. 153/2023) e la L. 170/2010.
///
/// Principio etico e deontologico inscritto nel codice:
/// Non esiste gruppo di controllo. Il prospetto documenta descrittivamente
/// il percorso dello studente con gli strumenti attivi, senza trarre conclusioni
/// indebite o automatiche sulla revoca delle misure.
public nonisolated enum GloReportComposer {

    public struct Input: Sendable {
        public let instituteName: String
        public let studentName: String
        public let classInfo: String
        public let programTitle: String
        public let compensatory: [String]
        public let dispensatory: [String]
        public let entries: [GloLogEntry]
        public let schoolYear: String

        public init(
            instituteName: String,
            studentName: String,
            classInfo: String,
            programTitle: String,
            compensatory: [String],
            dispensatory: [String],
            entries: [GloLogEntry],
            schoolYear: String = "2025/2026"
        ) {
            self.instituteName = instituteName
            self.studentName = studentName
            self.classInfo = classInfo
            self.programTitle = programTitle
            self.compensatory = compensatory
            self.dispensatory = dispensatory
            self.entries = entries
            self.schoolYear = schoolYear
        }
    }

    public static func compose(_ input: Input) -> String {
        var parts: [String] = []

        // 1. Intestazione
        let header = """
        # \(input.instituteName.isEmpty ? "Istituto Scolastico" : input.instituteName)
        ## Monitoraggio di Efficacia delle Misure Educative e Didattiche
        **Verifica periodica / finale GLO — Anno Scolastico \(input.schoolYear)**
        *Riferimenti normativi: D.I. 182/2020 come modificato dal D.I. 153/2023 — L. 170/2010 e D.M. 5669/2011*

        ---

        **Alunno/a:** \(input.studentName) — **Classe:** \(input.classInfo)
        **Percorso personalizzato:** \(input.programTitle)
        """
        parts.append(header)

        // 2. Misure personalizzate deliberate
        var measuresSection = "### Misure Deliberate nel Piano Personalizzato\n"
        if input.compensatory.isEmpty && input.dispensatory.isEmpty {
            measuresSection += "\n*Nessuna misura formalizzata a sistema.*"
        } else {
            if !input.compensatory.isEmpty {
                measuresSection += "\n**Misure compensative e strumenti da banco:**\n"
                for m in input.compensatory {
                    let text = MeasureCatalog.matching(m)?.text ?? m
                    measuresSection += "- \(text)\n"
                }
            }
            if !input.dispensatory.isEmpty {
                measuresSection += "\n**Misure dispensative adottate:**\n"
                for m in input.dispensatory {
                    let text = MeasureCatalog.matching(m)?.text ?? m
                    measuresSection += "- \(text)\n"
                }
            }
        }
        parts.append(measuresSection)

        // 3. Registro degli esiti e delle prove svolte
        var entriesSection = "### Registro Cronologico delle Verifiche e delle Attività Monitorate\n"
        let sortedEntries = input.entries.sorted { $0.date < $1.date }

        if sortedEntries.isEmpty {
            entriesSection += "\n*Nessuna verifica registrata nel diario di bordo per il periodo selezionato.*"
        } else {
            entriesSection += """
            \n| Data | Argomento / Attività | Formato didattico | Dimensione PEI | Autonomia rilevata | Tempo (usati / concessi) | Esito / Note |
            |---|---|---|---|---|---|---|
            """
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "it_IT")

            for entry in sortedEntries {
                let dateStr = formatter.string(from: entry.date)
                let timeStr: String
                if let allowed = entry.minutesAllowed, let used = entry.minutesUsed {
                    timeStr = "\(used)/\(allowed) min"
                } else if let allowed = entry.minutesAllowed {
                    timeStr = "conc. \(allowed) min"
                } else if let used = entry.minutesUsed {
                    timeStr = "usati \(used) min"
                } else {
                    timeStr = "-"
                }
                let scoreOrNotes = entry.score.isEmpty ? (entry.notes.isEmpty ? "-" : entry.notes) : (entry.notes.isEmpty ? entry.score : "\(entry.score) — \(entry.notes)")
                entriesSection += "\n| \(dateStr) | \(entry.topic) | \(entry.formatUsed) | \(entry.dimension.shortLabel) | \(entry.autonomyLevel) | \(timeStr) | \(scoreOrNotes) |"
            }
        }
        parts.append(entriesSection)

        // 4. Sintesi per le 4 Dimensioni Ministeriali
        var dimensionsSection = "### Quadro di Sintesi per Dimensioni Ministeriali (D.I. 182/2020)\n"
        for dim in PeiDimension.allCases {
            let count = sortedEntries.filter { $0.dimension == dim }.count
            dimensionsSection += "\n- **\(dim.rawValue)**: \(Plural.it(count, "osservazione registrata", "osservazioni registrate"))"
        }
        parts.append(dimensionsSection)

        // 5. Monitoraggio empirico del tempo aggiuntivo (minuti concessi vs minuti usati)
        let timedEntries = sortedEntries.filter { $0.minutesAllowed != nil && $0.minutesUsed != nil }
        if !timedEntries.isEmpty {
            var timeSection = "### Monitoraggio dei Tempi Aggiuntivi (L. 170/2010 e D.I. 182/2020)\n"
            let totalAllowed = timedEntries.compactMap(\.minutesAllowed).reduce(0, +)
            let totalUsed = timedEntries.compactMap(\.minutesUsed).reduce(0, +)
            let avgPct = totalAllowed > 0 ? Int((Double(totalUsed) / Double(totalAllowed) * 100).rounded()) : 0

            timeSection += "\n- **Prove con tracciamento orario**: \(timedEntries.count)"
            timeSection += "\n- **Totale minuti concessi complessivi**: \(totalAllowed) min"
            timeSection += "\n- **Totale minuti effettivi utilizzati**: \(totalUsed) min"
            timeSection += "\n- **Percentuale media di utilizzo del tempo concesso**: \(avgPct)%"
            timeSection += "\n\n*La metrica documenta empiricamente l'adeguatezza del tempo maggiorato concesso allo studente rispetto alla durata curricolare della classe, senza ricorso a costanti teoriche arbitrarie.*"
            parts.append(timeSection)
        }

        // 5. Clausola etica e metodologica inderogabile (il registro descrive, non conclude)
        let ethicalClause = """
        ### Nota Metodologica e Valutativa per il GLO e la Dirigenza
        > **Avvertenza deontologica:** Il presente prospetto costituisce documentazione descrittiva del percorso svolto dallo studente con l'ausilio delle misure compensative e dispensative deliberate. In assenza di gruppo di controllo, gli esiti positivi documentano l'efficacia e la funzionalità dell'adattamento didattico e non costituiscono motivazione scientifica o presupposto per la revoca degli strumenti concessi a tutela del diritto allo studio (D.I. 182/2020, Linee Guida D.M. 5669/2011).

        ---

        **Data di redazione:** \(currentDateFormatted())

        **Firma Docente Coordinatore / Sostegno:** ___________________________

        **Firma Docenti Consiglio di Classe:** ___________________________

        **Visto del Dirigente Scolastico:** ___________________________
        """
        parts.append(ethicalClause)

        return parts.joined(separator: "\n\n")
    }

    private static func currentDateFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: Date())
    }
}
