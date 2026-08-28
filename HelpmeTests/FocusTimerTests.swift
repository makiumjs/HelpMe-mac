import XCTest
@testable import Helpme

/// AC5, parte timer: pause attive e badge visibili.
///
/// Prima a fine sessione il timer si azzerava e basta: i badge venivano
/// assegnati e mai mostrati, e la pausa attiva prevista dalla specifica
/// non esisteva.
@MainActor
final class FocusTimerTests: XCTestCase {

    private func makeViewModel() -> StudentReaderViewModel {
        StudentReaderViewModel(
            appViewModel: AppViewModel(modelContext: .init(PersistenceController(inMemory: true).container))
        )
    }

    // MARK: - Fasi

    func testStartsIdleAtTheSelectedPreset() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertFalse(viewModel.isTimerRunning)
        XCTAssertEqual(viewModel.secondsRemaining, viewModel.selectedPresetMinutes * 60)
    }

    func testStartingEntersFocusing() {
        let viewModel = makeViewModel()
        viewModel.startFocusTimer()

        XCTAssertEqual(viewModel.phase, .focusing)
        XCTAssertTrue(viewModel.isTimerRunning)
    }

    func testPauseKeepsThePhaseButStopsTheClock() {
        let viewModel = makeViewModel()
        viewModel.startFocusTimer()
        viewModel.pauseFocusTimer()

        XCTAssertEqual(viewModel.phase, .focusing, "Mettere in pausa non abbandona la sessione")
        XCTAssertFalse(viewModel.isTimerRunning)
        XCTAssertGreaterThan(viewModel.secondsRemaining, 0)
    }

    func testTogglingAlternatesRunningAndPaused() {
        let viewModel = makeViewModel()
        viewModel.toggleFocusTimer()
        XCTAssertTrue(viewModel.isTimerRunning)
        viewModel.toggleFocusTimer()
        XCTAssertFalse(viewModel.isTimerRunning)
        viewModel.toggleFocusTimer()
        XCTAssertTrue(viewModel.isTimerRunning)
    }

    func testChangingPresetResetsToIdle() {
        let viewModel = makeViewModel()
        viewModel.startFocusTimer()
        viewModel.resetTimer(minutes: 25)

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertFalse(viewModel.isTimerRunning)
        XCTAssertEqual(viewModel.selectedPresetMinutes, 25)
        XCTAssertEqual(viewModel.secondsRemaining, 25 * 60)
    }

    // MARK: - Pausa attiva

    /// Il cuore del punto aperto: a fine sessione non ci si azzera, si
    /// propone una pausa attiva con un'attività concreta.
    func testCompletingASessionProposesAnActiveBreak() async throws {
        let viewModel = makeViewModel()
        try await runOneSecondSession(viewModel)

        XCTAssertEqual(viewModel.phase, .breakSuggested)
        XCTAssertEqual(viewModel.completedSessions, 1)
        XCTAssertFalse(viewModel.isTimerRunning, "La pausa è proposta, non imposta")

        let suggestion = try XCTUnwrap(viewModel.currentBreak)
        XCTAssertFalse(suggestion.instruction.isEmpty)
        XCTAssertEqual(viewModel.secondsRemaining, suggestion.seconds)
    }

    func testStartingTheBreakEntersOnBreak() async throws {
        let viewModel = makeViewModel()
        try await runOneSecondSession(viewModel)

        viewModel.startBreak()

        XCTAssertEqual(viewModel.phase, .onBreak)
        XCTAssertTrue(viewModel.isTimerRunning)
    }

    /// Chi è nel flusso deve poter tirare dritto senza combattere con l'app.
    func testSkippingTheBreakReturnsToIdleReadyForAnotherSession() async throws {
        let viewModel = makeViewModel()
        try await runOneSecondSession(viewModel)

        viewModel.skipBreak()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertNil(viewModel.currentBreak)
        XCTAssertEqual(viewModel.secondsRemaining, viewModel.selectedPresetMinutes * 60)
        XCTAssertEqual(viewModel.completedSessions, 1, "La sessione fatta resta contata")
    }

    func testBreakSuggestionsRotateSoTheyAreNotAlwaysTheSame() {
        let first = ActiveBreak.suggestion(afterSession: 1)
        let second = ActiveBreak.suggestion(afterSession: 2)
        XCTAssertNotEqual(first.id, second.id)

        // Deterministica: la stessa sessione propone sempre la stessa pausa.
        XCTAssertEqual(ActiveBreak.suggestion(afterSession: 1).id, first.id)
        // E ricomincia dal principio dopo aver esaurito il catalogo.
        XCTAssertEqual(ActiveBreak.suggestion(afterSession: 1 + ActiveBreak.catalog.count).id, first.id)
    }

    func testEveryBreakSuggestsSomethingConcreteAndBounded() {
        for activeBreak in ActiveBreak.catalog {
            XCTAssertFalse(activeBreak.title.isEmpty)
            XCTAssertGreaterThan(activeBreak.instruction.count, 25, "«\(activeBreak.title)» è troppo vaga")
            XCTAssertGreaterThanOrEqual(activeBreak.seconds, 60)
            XCTAssertLessThanOrEqual(activeBreak.seconds, 300, "Una pausa lunga rompe il ritmo dello studio")
        }
    }

    // MARK: - Badge

    func testBadgesAreEarnedAtTheirMilestones() {
        XCTAssertTrue(FocusBadge.earned(afterSessions: 0).isEmpty)
        XCTAssertEqual(FocusBadge.earned(afterSessions: 1).count, 1)
        XCTAssertEqual(FocusBadge.earned(afterSessions: 3).count, 2)
        XCTAssertEqual(FocusBadge.earned(afterSessions: 10).count, FocusBadge.catalog.count)
    }

    func testNextBadgePointsAtTheUpcomingMilestone() {
        XCTAssertEqual(FocusBadge.next(afterSessions: 0)?.requiredSessions, 1)
        XCTAssertEqual(FocusBadge.next(afterSessions: 1)?.requiredSessions, 3)
        XCTAssertNil(FocusBadge.next(afterSessions: 99), "Presi tutti, non resta un prossimo")
    }

    func testCatalogIsOrderedByDifficulty() {
        let required = FocusBadge.catalog.map(\.requiredSessions)
        XCTAssertEqual(required, required.sorted(), "I traguardi vanno dal più facile al più difficile")
        XCTAssertEqual(Set(FocusBadge.catalog.map(\.id)).count, FocusBadge.catalog.count, "Id duplicati")
    }

    /// Il badge appena preso viene esposto per essere festeggiato: prima
    /// veniva assegnato e non lo vedeva nessuno.
    func testFirstCompletedSessionSurfacesTheNewBadge() async throws {
        let viewModel = makeViewModel()
        XCTAssertNil(viewModel.newlyEarnedBadge)

        try await runOneSecondSession(viewModel)

        let badge = try XCTUnwrap(viewModel.newlyEarnedBadge)
        XCTAssertEqual(badge.requiredSessions, 1)
        XCTAssertEqual(viewModel.earnedBadges.map(\.id), [badge.id])

        viewModel.dismissBadgeCelebration()
        XCTAssertNil(viewModel.newlyEarnedBadge)
    }

    /// Una sessione che non sblocca niente non deve far comparire un
    /// festeggiamento vuoto.
    func testSessionWithoutANewMilestoneCelebratesNothing() async throws {
        let viewModel = makeViewModel()
        try await runOneSecondSession(viewModel)   // 1ª: sblocca il primo badge
        viewModel.skipBreak()
        viewModel.dismissBadgeCelebration()

        try await runOneSecondSession(viewModel)   // 2ª: nessun traguardo a 2

        XCTAssertEqual(viewModel.completedSessions, 2)
        XCTAssertNil(viewModel.newlyEarnedBadge)
    }

    // MARK: - Avanzamento

    func testProgressGoesFromZeroTowardsOne() {
        let viewModel = makeViewModel()
        viewModel.resetTimer(minutes: 10)
        XCTAssertEqual(viewModel.progressFraction, 0, accuracy: 0.001)

        viewModel.startFocusTimer()
        viewModel.pauseFocusTimer()
        XCTAssertGreaterThanOrEqual(viewModel.progressFraction, 0)
        XCTAssertLessThanOrEqual(viewModel.progressFraction, 1)
    }

    // MARK: - Helper

    /// Fa scadere una sessione di studio senza aspettare quindici minuti:
    /// il preset si porta a un minuto e si consuma il conteggio reale.
    private func runOneSecondSession(_ viewModel: StudentReaderViewModel) async throws {
        // Il conteggio si ricava da una scadenza assoluta, quindi la fase
        // scade davvero: non c'è nessuna simulazione, solo una durata breve.
        viewModel.resetTimer(seconds: 1, presetMinutes: 1)
        viewModel.startFocusTimer()

        try await waitUntil(timeout: 5) { viewModel.phase == .breakSuggested }
    }

    private func waitUntil(
        timeout: TimeInterval,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Condizione non raggiunta entro \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
