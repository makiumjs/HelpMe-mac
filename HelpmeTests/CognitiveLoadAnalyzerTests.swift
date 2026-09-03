import XCTest
@testable import Helpme

final class CognitiveLoadAnalyzerTests: XCTestCase {

    func testFindSimplificationsDetectsBureaucraticWords() {
        let text = "Il candidato deve altresì rammentare di ottemperare all'incombenza con esiguo ritardo."
        let simpls = CognitiveLoadAnalyzer.findSimplifications(in: text)

        let words = simpls.map(\.complexWord)
        XCTAssertTrue(words.contains("altresi") || words.contains("altresì"))
        XCTAssertTrue(words.contains("rammentare"))
        XCTAssertTrue(words.contains("ottemperare"))
        XCTAssertTrue(words.contains("incombenza"))
        XCTAssertTrue(words.contains("esiguo"))

        if let alt = simpls.first(where: { $0.complexWord.starts(with: "altres") }) {
            XCTAssertEqual(alt.suggestedAlternative, "inoltre")
        }
    }

    func testDetectDoubleNegations() {
        let sentenceWithDoubleNegation = "Non è impossibile comprendere il funzionamento del circuito."
        XCTAssertTrue(CognitiveLoadAnalyzer.hasDoubleNegation(sentenceWithDoubleNegation))

        let sentenceWithNegativeWords = "Senza escludere le conseguenze del trattato di pace."
        XCTAssertTrue(CognitiveLoadAnalyzer.hasDoubleNegation(sentenceWithNegativeWords))

        let simplePositiveSentence = "È facile comprendere il funzionamento del circuito."
        XCTAssertFalse(CognitiveLoadAnalyzer.hasDoubleNegation(simplePositiveSentence))

        let singleNegation = "Non capisco questa regola."
        XCTAssertFalse(CognitiveLoadAnalyzer.hasDoubleNegation(singleNegation))
    }

    func testAssessCognitiveLoadIdentifiesExcessiveLoad() {
        let denseAcademicText = """
        Allorché il candidato si accinga a ponderare le molteplici implicazioni socio-economiche scaturite dal repentino collasso delle istituzioni feudali, non è insussistente l'esigenza di delucidare altresì i presupposti giuridici che hanno corroborato la transizione verso il medesimo ordinamento comunale, senza tralasciare di adempiere alla disamina delle fonti primarie.
        """

        let assessment = CognitiveLoadAnalyzer.assess(text: denseAcademicText, isExam: true)

        XCTAssertTrue(assessment.longSentencesCount >= 1)
        XCTAssertTrue(assessment.doubleNegationCount >= 1)
        XCTAssertFalse(assessment.simplifications.isEmpty)
        XCTAssertTrue(assessment.loadLevel == .high || assessment.loadLevel == .excessive)
        XCTAssertFalse(assessment.recommendations.isEmpty)
    }

    func testSentenceReadingEnrichedWithCognitiveLoadInfo() {
        let sentence = "Non è impossibile ottemperare alla richiesta."
        let reading = ReadabilityAnalyzer.reading(of: sentence)

        XCTAssertTrue(reading.hasDoubleNegation)
        XCTAssertTrue(reading.reasons.contains { $0.contains("doppia negazione") })
        XCTAssertTrue(reading.reasons.contains { $0.contains("ottemperare") })
    }
}
