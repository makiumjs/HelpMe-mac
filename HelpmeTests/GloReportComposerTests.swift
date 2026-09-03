import XCTest
@testable import Helpme

final class GloReportComposerTests: XCTestCase {

    func testReportContainsStudentAndSchoolHeader() {
        let studentId = UUID()
        let report = GloReportComposer.compose(.init(
            instituteName: "Liceo Scientifico Leonardo da Vinci",
            studentName: "Federico Chiesa",
            classInfo: "3ª B",
            programTitle: "Programmazione personalizzata (D.I. 182/2020)",
            compensatory: ["comp.calcolatrice"],
            dispensatory: ["disp.tempi"],
            entries: []
        ))

        XCTAssertTrue(report.contains("Liceo Scientifico Leonardo da Vinci"))
        XCTAssertTrue(report.contains("Federico Chiesa"))
        XCTAssertTrue(report.contains("3ª B"))
        XCTAssertTrue(report.contains("D.I. 182/2020 come modificato dal D.I. 153/2023"))
    }

    func testReportListsCompensatoryAndDispensatoryMeasures() {
        let report = GloReportComposer.compose(.init(
            instituteName: "I.C. Manzoni",
            studentName: "Sara Neri",
            classInfo: "1ª A",
            programTitle: "Piano Didattico Personalizzato (L. 170/2010)",
            compensatory: ["comp.formulari", "comp.calcolatrice"],
            dispensatory: ["disp.tempi"],
            entries: []
        ))

        XCTAssertTrue(report.contains("Misure compensative e strumenti da banco"))
        XCTAssertTrue(report.contains("Formulari, tabelle e schemi"))
        XCTAssertTrue(report.contains("Calcolatrice non programmabile"))
        XCTAssertTrue(report.contains("Tempi aggiuntivi fino al 30%"))
    }

    func testReportChronologicalTableIncludesScoreAndAutonomy() {
        let studentId = UUID()
        let entry1 = GloLogEntry(
            studentId: studentId,
            studentName: "Marco Rossi",
            date: Date(timeIntervalSince1970: 1729000000), // Ottobre 2024
            topic: "Verifica sui Vulcani",
            formatUsed: "Verifica Equipollente",
            dimension: .cognitive,
            autonomyLevel: "Autonomo con schema",
            notes: "Ottima comprensione",
            score: "8/10",
            minutesAllowed: 80,
            minutesUsed: 65
        )
        let entry2 = GloLogEntry(
            studentId: studentId,
            studentName: "Marco Rossi",
            date: Date(timeIntervalSince1970: 1732000000), // Novembre 2024
            topic: "Esposizione orale",
            formatUsed: "Mappa Concettuale",
            dimension: .communication,
            autonomyLevel: "Guida iniziale del docente",
            notes: "Esposizione chiara con mappa",
            score: "7.5/10"
        )

        let report = GloReportComposer.compose(.init(
            instituteName: "I.I.S. Galilei",
            studentName: "Marco Rossi",
            classInfo: "2ª C",
            programTitle: "PDP",
            compensatory: ["comp.mappe"],
            dispensatory: [],
            entries: [entry1, entry2]
        ))

        XCTAssertTrue(report.contains("| Verifica sui Vulcani | Verifica Equipollente | Cognitiva & Apprendimento | Autonomo con schema | 65/80 min | 8/10 — Ottima comprensione |"))
        XCTAssertTrue(report.contains("| Esposizione orale | Mappa Concettuale | Comunicazione & Linguaggi | Guida iniziale del docente | - | 7.5/10 — Esposizione chiara con mappa |"))
        XCTAssertTrue(report.contains("Monitoraggio dei Tempi Aggiuntivi"))
        XCTAssertTrue(report.contains("80 min"))
    }

    func testReportIncludesFourPeiDimensionsSummary() {
        let studentId = UUID()
        let entry = GloLogEntry(
            studentId: studentId,
            studentName: "Anna Frank",
            topic: "Prova",
            formatUsed: "Testo Chiaro",
            dimension: .autonomy,
            autonomyLevel: "Totale",
            notes: "",
            score: "9/10"
        )

        let report = GloReportComposer.compose(.init(
            instituteName: "Scuola Media",
            studentName: "Anna Frank",
            classInfo: "3ª D",
            programTitle: "PEI",
            compensatory: [],
            dispensatory: [],
            entries: [entry]
        ))

        XCTAssertTrue(report.contains("Dimensione dell'Autonomia e dell'Orientamento**: 1 osservazione registrata"))
        XCTAssertTrue(report.contains("Dimensione Cognitiva, Neuropsicologica e dell'Apprendimento**: 0 osservazioni registrate"))
    }

    /// Principio vincolante: non esiste gruppo di controllo e il registro descrive, non conclude.
    func testReportIncludesEthicalNonRevocationClause() {
        let report = GloReportComposer.compose(.init(
            instituteName: "Liceo",
            studentName: "Studente",
            classInfo: "1A",
            programTitle: "PDP",
            compensatory: [],
            dispensatory: [],
            entries: []
        ))

        XCTAssertTrue(report.contains("In assenza di gruppo di controllo"))
        XCTAssertTrue(report.contains("non costituiscono motivazione scientifica o presupposto per la revoca degli strumenti concessi"))
        XCTAssertTrue(report.contains("Firma Docente Coordinatore"))
        XCTAssertTrue(report.contains("Visto del Dirigente Scolastico"))
    }
}
