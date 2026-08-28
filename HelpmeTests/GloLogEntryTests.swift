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
}
