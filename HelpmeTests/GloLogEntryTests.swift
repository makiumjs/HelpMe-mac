import XCTest
@testable import Helpme

final class GloLogEntryTests: XCTestCase {
    func testAllFourDimensionsAvailable() {
        let dimensions = PeiDimension.allCases
        XCTAssertEqual(dimensions.count, 4)
        
        XCTAssertTrue(dimensions.contains(.cognitive))
        XCTAssertTrue(dimensions.contains(.autonomy))
        XCTAssertTrue(dimensions.contains(.communication))
        XCTAssertTrue(dimensions.contains(.relational))
    }
    
    func testGloEntryCreation() {
        let studentId = UUID()
        let entry = GloLogEntry(
            studentId: studentId,
            studentName: "Marco Rossi",
            topic: "Equazioni di secondo grado",
            formatUsed: "Formulario con passaggi guidati",
            dimension: .cognitive,
            autonomyLevel: "Autonomia completa con formulario",
            notes: "Ha svolto l'esercizio senza ansia da prestazione."
        )
        
        XCTAssertEqual(entry.studentId, studentId)
        XCTAssertEqual(entry.dimension, .cognitive)
        XCTAssertEqual(entry.dimension.shortLabel, "Cognitiva & Apprendimento")
        XCTAssertFalse(entry.dimension.iconName.isEmpty)
    }

    func testTimeRatioCalculationWhenTimeSaved() {
        let entry = GloLogEntry(
            studentId: UUID(),
            studentName: "Marco Rossi",
            topic: "Verifica di Scienze",
            formatUsed: "Verifica Equipollente",
            dimension: .cognitive,
            notes: "",
            score: "8/10",
            minutesAllowed: 80,
            minutesUsed: 65
        )

        XCTAssertEqual(entry.minutesAllowed, 80)
        XCTAssertEqual(entry.minutesUsed, 65)
        XCTAssertEqual(entry.timeRatioFormatted, "65 min usati su 80 concessi (81% — risparmiati 15 min)")
    }

    func testTimeRatioCalculationWhenTimeOverspent() {
        let entry = GloLogEntry(
            studentId: UUID(),
            studentName: "Marco Rossi",
            topic: "Verifica di Storia",
            formatUsed: "Verifica Equipollente",
            dimension: .cognitive,
            notes: "",
            score: "6/10",
            minutesAllowed: 60,
            minutesUsed: 65
        )

        XCTAssertEqual(entry.timeRatioFormatted, "65 min usati su 60 concessi (108% — supero di 5 min)")
    }

    func testTimeRatioCalculationWhenNil() {
        let entry = GloLogEntry(
            studentId: UUID(),
            studentName: "Marco Rossi",
            topic: "Attività",
            formatUsed: "Mappa",
            dimension: .autonomy
        )

        XCTAssertNil(entry.timeRatioFormatted)
    }
}

