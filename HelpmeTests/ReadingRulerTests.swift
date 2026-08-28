import XCTest
@testable import Helpme

/// AC3: il righello smette di scappare durante il trascinamento.
///
/// Il difetto era usare `value.location.y`, espresso nello spazio locale del
/// rettangolo che si sta muovendo: il riferimento si spostava a ogni frame.
/// Questi test descrivono il comportamento corretto — spostamento pari alla
/// distanza percorsa dal dito — e sono la rete che impedisce di riscriverlo
/// nel modo di prima.
final class ReadingRulerTests: XCTestCase {

    private let container: CGFloat = 600
    private let ruler: CGFloat = 48

    private func offset(from start: CGFloat, by translation: CGFloat) -> CGFloat {
        ReadingRuler.clampedOffset(
            start: start,
            translation: translation,
            containerHeight: container,
            rulerHeight: ruler
        )
    }

    // MARK: - Movimento

    func testDragMovesByExactlyTheTranslation() {
        XCTAssertEqual(offset(from: 100, by: 60), 160)
        XCTAssertEqual(offset(from: 100, by: -60), 40)
    }

    func testZeroTranslationLeavesTheRulerStill() {
        XCTAssertEqual(offset(from: 137, by: 0), 137)
    }

    /// Il cuore del difetto: durante un solo gesto ogni aggiornamento parte
    /// dallo stesso ancoraggio, quindi la posizione dipende solo da quanto
    /// il dito si è mosso in totale — non dalla frequenza degli eventi.
    func testPositionDependsOnlyOnTotalTranslationWithinAGesture() {
        let anchor: CGFloat = 120

        // Un gesto riportato in un colpo solo…
        let inOneGo = offset(from: anchor, by: 90)

        // …e lo stesso gesto riportato in tanti piccoli aggiornamenti.
        var last: CGFloat = anchor
        for step in stride(from: CGFloat(10), through: 90, by: 10) {
            last = offset(from: anchor, by: step)
        }

        XCTAssertEqual(inOneGo, last, "Il risultato non deve dipendere da quanti eventi arrivano")
        XCTAssertEqual(last, 210)
    }

    /// Trascinare avanti e indietro deve riportare esattamente al punto di
    /// partenza: qualunque deriva qui si vedrebbe a ogni riga letta.
    func testDraggingBackAndForthDoesNotDrift() {
        var position: CGFloat = 200
        for _ in 0..<50 {
            position = offset(from: position, by: 17)
            position = offset(from: position, by: -17)
        }
        XCTAssertEqual(position, 200)
    }

    // MARK: - Limiti

    func testCannotBeDraggedAboveTheTop() {
        XCTAssertEqual(offset(from: 20, by: -500), 0)
    }

    func testCannotBeDraggedBelowTheBottom() {
        XCTAssertEqual(offset(from: 500, by: 500), container - ruler)
    }

    func testClampingIsIdempotentAtTheEdges() {
        let bottom = offset(from: 500, by: 500)
        XCTAssertEqual(offset(from: bottom, by: 300), bottom)

        let top = offset(from: 20, by: -500)
        XCTAssertEqual(offset(from: top, by: -300), top)
    }

    /// Finestra più piccola del righello: nessun offset negativo, che
    /// spingerebbe il righello fuori dall'area di lettura.
    func testContainerSmallerThanRulerPinsToZero() {
        let result = ReadingRuler.clampedOffset(
            start: 50, translation: 30, containerHeight: 30, rulerHeight: 48
        )
        XCTAssertEqual(result, 0)
    }

    /// Rimpicciolendo la finestra il righello deve rientrare da solo.
    func testShrinkingTheContainerPullsTheRulerBackIn() {
        let result = ReadingRuler.clampedOffset(
            start: 550, translation: 0, containerHeight: 300, rulerHeight: ruler
        )
        XCTAssertEqual(result, 300 - ruler)
    }

    // MARK: - Tastiera e VoiceOver

    func testKeyboardStepMovesInBothDirections() {
        let start: CGFloat = 200
        XCTAssertEqual(offset(from: start, by: ReadingRuler.keyboardStep), start + ReadingRuler.keyboardStep)
        XCTAssertEqual(offset(from: start, by: -ReadingRuler.keyboardStep), start - ReadingRuler.keyboardStep)
    }

    /// Il passo deve avvicinarsi all'altezza di una riga: troppo piccolo
    /// richiederebbe decine di pressioni per scendere di un capoverso.
    func testKeyboardStepIsAUsefulSize() {
        XCTAssertGreaterThanOrEqual(ReadingRuler.keyboardStep, 12)
        XCTAssertLessThanOrEqual(ReadingRuler.keyboardStep, 48)
    }
}
