import XCTest
@testable import Helpme

final class DidacticPromptTests: XCTestCase {
    func testEquipollenteExamPromptTemplate() {
        let format = DidacticFormat.equipollenteExam
        let template = format.systemPromptTemplate
        
        XCTAssertTrue(template.contains("VERIFICA EQUIPOLLENTE"))
        XCTAssertTrue(template.contains("+30%"))
        XCTAssertTrue(template.contains("Griglia di Valutazione"))
        XCTAssertTrue(template.contains("{INTEREST}"))
    }
    
    func testDeskCheatSheetPrompt() {
        let format = DidacticFormat.deskCheatSheet
        let template = format.systemPromptTemplate
        
        XCTAssertTrue(template.contains("FORMULARIO & SCHEDA DA BANCO"))
        XCTAssertTrue(template.contains("L. 170/2010"))
    }
    
    func testAllFormatsHavePrompts() {
        for format in DidacticFormat.allCases {
            XCTAssertFalse(format.title.isEmpty)
            XCTAssertFalse(format.subtitle.isEmpty)
            XCTAssertFalse(format.systemPromptTemplate.isEmpty)
        }
    }
}
