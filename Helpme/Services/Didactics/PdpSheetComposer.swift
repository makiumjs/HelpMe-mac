import Foundation
public nonisolated enum PdpSheetComposer {

    public struct Input: Sendable {
        public let studentName: String
        public let classInfo: String
        public let programTitle: String
        public let programReference: String
        public let interest: String
        public let notes: String
        public let compensatory: [String]
        public let dispensatory: [String]

        public init(
            studentName: String, classInfo: String,
            programTitle: String, programReference: String,
            interest: String, notes: String,
            compensatory: [String], dispensatory: [String]
        ) {
            self.studentName = studentName
            self.classInfo = classInfo
            self.programTitle = programTitle
            self.programReference = programReference
            self.interest = interest
            self.notes = notes
            self.compensatory = compensatory
            self.dispensatory = dispensatory
        }
    }

    public static func compose(_ input: Input) -> String {
        var parts: [String] = []

        parts.append("""
        ## Scheda Sintesi PDP — \(input.studentName)

        **Classe:** \(input.classInfo)
        **Percorso:** \(input.programTitle)
        **Riferimento normativo:** \(input.programReference)
        """)
        let filed = fileByCategory(compensatory: input.compensatory, dispensatory: input.dispensatory)

        parts.append(section(
            "1. Strumenti compensativi attivi",
            measures: filed.compensative,
            emptyNote: "Nessuno strumento compensativo è stato indicato per questo alunno."
        ))

        parts.append(section(
            "2. Misure dispensative concordate",
            measures: filed.dispensative,
            emptyNote: "Nessuna misura dispensativa è stata indicata per questo alunno."
        ))
        let strategies = assessmentStrategies(
            compensatory: input.compensatory,
            dispensatory: input.dispensatory
        )
        if !strategies.isEmpty {
            parts.append(section("3. Strategie per le verifiche", measures: strategies, emptyNote: ""))
        }

        if !input.interest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("""
            ## 4. Leva motivazionale

            Gli esempi e le analogie proposti all'alunno partono da: **\(input.interest)**.
            """)
        }
        let didactic = StudentPseudonymizer.filterClinicalReferences(from: input.notes)
        if !didactic.isEmpty {
            parts.append("""
            ## 5. Osservazioni didattiche

            \(didactic)
            """)
        }

        parts.append("""
        ---

        *Scheda compilata dalle misure registrate nella scheda dell'alunno. \
        Le diciture seguono la normativa vigente e non sono state rielaborate.*
        """)

        return parts.joined(separator: "\n\n")
    }
    static func fileByCategory(
        compensatory: [String],
        dispensatory: [String]
    ) -> (compensative: [String], dispensative: [String]) {
        var comp: [String] = []
        var disp: [String] = []

        for (raw, fallbackIsCompensative) in compensatory.map({ ($0, true) }) + dispensatory.map({ ($0, false) }) {
            switch MeasureCatalog.matching(raw)?.category {
            case .compensative: comp.append(raw)
            case .dispensative: disp.append(raw)
            case .assessment:   disp.append(raw)
            case nil:           fallbackIsCompensative ? comp.append(raw) : disp.append(raw)
            }
        }
        return (comp, disp)
    }

    private static func section(_ title: String, measures: [String], emptyNote: String) -> String {
        guard !measures.isEmpty else { return "## \(title)\n\n\(emptyNote)" }

        let rows = measures.map { raw -> String in
            guard let known = MeasureCatalog.matching(raw) else { return "- \(raw)" }
            return "- \(known.text) *(\(known.reference))*"
        }
        return "## \(title)\n\n" + rows.joined(separator: "\n")
    }
    static func assessmentStrategies(compensatory: [String], dispensatory: [String]) -> [String] {
        let chosen = (compensatory + dispensatory).compactMap { MeasureCatalog.matching($0)?.id }
        var derived: [String] = []

        func add(_ id: String) {
            guard let measure = MeasureCatalog.measure(id: id), !derived.contains(measure.text) else { return }
            derived.append(measure.text)
        }

        if chosen.contains("disp.lettura-alta-voce") || chosen.contains("comp.sintesi-vocale") {
            add("val.lettura-consegna")
        }
        if chosen.contains("disp.dettatura") || chosen.contains("disp.memorizzazione") {
            add("val.strutturate")
        }
        if chosen.contains("comp.formulari") || chosen.contains("comp.mappe") {
            add("val.strumenti-in-prova")
        }
        if chosen.contains("disp.tempi") || chosen.contains("disp.quantita") {
            add("val.suddivisione")
        }
        if chosen.contains("disp.ortografia") {
            add("val.contenuto")
        }
        add("val.programmate")

        return derived
    }
}
