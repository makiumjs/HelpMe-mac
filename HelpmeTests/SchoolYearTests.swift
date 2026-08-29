import XCTest
@testable import Helpme

/// L'anno scolastico finisce stampato su documenti che entrano nel fascicolo
/// dell'alunno. Era una costante nel sorgente, e come tutte le costanti di
/// quel tipo era gia' scaduta quando qualcuno se n'e' accorto.
final class SchoolYearTests: XCTestCase {

    private func il(_ giorno: Int, _ mese: Int, _ anno: Int) -> Date {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendario.date(from: DateComponents(year: anno, month: mese, day: giorno))!
    }

    func testDuringTheSchoolYearItNamesThatYear() {
        XCTAssertEqual(SchoolInfo.currentSchoolYear(on: il(15, 10, 2026)), "A.S. 2026/2027")
        XCTAssertEqual(SchoolInfo.currentSchoolYear(on: il(3, 2, 2027)), "A.S. 2026/2027")
        XCTAssertEqual(SchoolInfo.currentSchoolYear(on: il(10, 6, 2027)), "A.S. 2026/2027")
    }

    /// Il caso che ha fatto trovare il difetto: fine agosto, quando i docenti
    /// di sostegno preparano il materiale per settembre.
    func testInLateAugustItAlreadyNamesTheYearAboutToStart() {
        XCTAssertEqual(SchoolInfo.currentSchoolYear(on: il(29, 8, 2026)), "A.S. 2026/2027",
                       "Un PEI preparato a fine agosto riguarda l'anno che comincia, non quello finito.")
        XCTAssertEqual(SchoolInfo.currentSchoolYear(on: il(1, 8, 2026)), "A.S. 2026/2027")
    }

    func testInJulyItStillNamesTheYearJustEnded() {
        XCTAssertEqual(SchoolInfo.currentSchoolYear(on: il(31, 7, 2026)), "A.S. 2025/2026")
    }

    /// La ragione per cui esiste questa funzione: il valore predefinito non
    /// deve poter invecchiare nel sorgente.
    func testTheDefaultIsNeverStale() {
        let atteso = SchoolInfo.currentSchoolYear()
        XCTAssertEqual(SchoolInfo().schoolYear, atteso)
        XCTAssertFalse(atteso.isEmpty)
    }
}
