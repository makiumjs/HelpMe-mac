import XCTest
import SwiftData
@testable import Helpme

/// Il blocco amministratore protegge la configurazione dell'IA: la chiave
/// la inserisce chi installa l'app, non il docente. Non è un confine di
/// sicurezza contro un amministratore della macchina — che può comunque
/// leggere il portachiavi — ma deve impedire in modo affidabile le
/// modifiche per sbaglio o curiosità, e resistere a un tentativo a forza
/// bruta della password.
final class AdminLockTests: XCTestCase {

    // MARK: - PasswordHasher

    func testCorrectPasswordVerifies() {
        let record = try! XCTUnwrap(PasswordHasher.makeRecord(password: "una-password-vera", iterations: 100))
        XCTAssertTrue(PasswordHasher.verify(password: "una-password-vera", against: record))
    }

    func testWrongPasswordIsRejected() {
        let record = try! XCTUnwrap(PasswordHasher.makeRecord(password: "una-password-vera", iterations: 100))
        XCTAssertFalse(PasswordHasher.verify(password: "un-tentativo-sbagliato", against: record))
    }

    func testEmptyPasswordDoesNotAccidentallyVerify() {
        let record = try! XCTUnwrap(PasswordHasher.makeRecord(password: "una-password-vera", iterations: 100))
        XCTAssertFalse(PasswordHasher.verify(password: "", against: record))
    }

    /// Due derivazioni della stessa password non devono coincidere: il salt
    /// casuale è quello che impedisce di precalcolare le password comuni.
    func testTwoRecordsOfTheSamePasswordDiffer() {
        let first = try! XCTUnwrap(PasswordHasher.makeRecord(password: "stessa-password", iterations: 100))
        let second = try! XCTUnwrap(PasswordHasher.makeRecord(password: "stessa-password", iterations: 100))
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(PasswordHasher.verify(password: "stessa-password", against: first))
        XCTAssertTrue(PasswordHasher.verify(password: "stessa-password", against: second))
    }

    func testMalformedRecordIsRejectedNotCrashed() {
        XCTAssertFalse(PasswordHasher.verify(password: "qualunque", against: "spazzatura-non-un-record"))
        XCTAssertFalse(PasswordHasher.verify(password: "qualunque", against: ""))
        XCTAssertFalse(PasswordHasher.verify(password: "qualunque", against: "solo:due"))
    }

    // MARK: - AdminLockState — i tentativi

    func testFirstAttemptsDoNotBlock() {
        var state = AdminLockState()
        state.recordFailure()
        state.recordFailure()
        XCTAssertFalse(state.isBlocked())
    }

    func testThirdFailureStartsTheDelay() {
        var state = AdminLockState()
        state.recordFailure()
        state.recordFailure()
        state.recordFailure()
        XCTAssertTrue(state.isBlocked())
        XCTAssertGreaterThan(state.remainingBlock(), 0)
    }

    /// Il ritardo raddoppia: un attacco a tappeto diventa via via più caro.
    func testDelayDoublesWithEachAdditionalFailure() {
        let now = Date()

        var afterThree = AdminLockState()
        afterThree.recordFailure(now: now)
        afterThree.recordFailure(now: now)
        afterThree.recordFailure(now: now)
        let firstDelay = afterThree.remainingBlock(now: now)

        var afterFour = afterThree
        afterFour.recordFailure(now: now)
        let secondDelay = afterFour.remainingBlock(now: now)

        XCTAssertEqual(secondDelay, firstDelay * 2, accuracy: 0.01)
    }

    func testSuccessResetsTheCounter() {
        var state = AdminLockState()
        state.recordFailure()
        state.recordFailure()
        state.recordFailure()
        XCTAssertTrue(state.isBlocked())

        state.recordSuccess()
        XCTAssertFalse(state.isBlocked())
        XCTAssertEqual(state.remainingBlock(), 0)
    }

    func testBlockExpiresOnItsOwn() {
        var state = AdminLockState()
        let start = Date()
        state.recordFailure(now: start)
        state.recordFailure(now: start)
        state.recordFailure(now: start)

        let stillBlocked = state.remainingBlock(now: start)
        XCTAssertTrue(state.isBlocked(now: start.addingTimeInterval(stillBlocked - 1)))
        XCTAssertFalse(state.isBlocked(now: start.addingTimeInterval(stillBlocked + 1)))
    }

    // MARK: - AdminLock — ciclo di vita completo

    @MainActor
    func testFreshLockHasNoPasswordSet() {
        let lock = makeIsolatedLock()
        XCTAssertFalse(lock.isPasswordSet)
        XCTAssertFalse(lock.isUnlocked)
    }

    @MainActor
    func testSettingTheInitialPasswordUnlocksImmediately() throws {
        let lock = makeIsolatedLock()
        try lock.setInitialPassword("password-abbastanza-lunga")

        XCTAssertTrue(lock.isPasswordSet)
        XCTAssertTrue(lock.isUnlocked)
    }

    @MainActor
    func testCannotSetAnInitialPasswordTwice() throws {
        let lock = makeIsolatedLock()
        try lock.setInitialPassword("prima-password-valida")

        XCTAssertThrowsError(try lock.setInitialPassword("seconda-password-valida")) { error in
            guard case AdminLock.LockError.passwordAlreadySet = error else {
                return XCTFail("Atteso .passwordAlreadySet, ricevuto \(error)")
            }
        }
    }

    @MainActor
    func testShortPasswordIsRejected() {
        let lock = makeIsolatedLock()
        XCTAssertThrowsError(try lock.setInitialPassword("corta")) { error in
            guard case AdminLock.LockError.passwordTooShort = error else {
                return XCTFail("Atteso .passwordTooShort, ricevuto \(error)")
            }
        }
        XCTAssertFalse(lock.isPasswordSet, "Una password rifiutata non deve restare salvata")
    }

    @MainActor
    func testLockingRequiresUnlockingAgainWithTheRightPassword() throws {
        let lock = makeIsolatedLock()
        try lock.setInitialPassword("password-corretta-123")
        lock.lock()
        XCTAssertFalse(lock.isUnlocked)

        XCTAssertThrowsError(try lock.unlock("password-sbagliata"))
        XCTAssertFalse(lock.isUnlocked)

        try lock.unlock("password-corretta-123")
        XCTAssertTrue(lock.isUnlocked)
    }

    @MainActor
    func testRepeatedWrongPasswordsEventuallyBlockUnlocking() throws {
        let lock = makeIsolatedLock()
        try lock.setInitialPassword("password-corretta-123")
        lock.lock()

        for _ in 0..<3 {
            XCTAssertThrowsError(try lock.unlock("sbagliata"))
        }

        // Anche la password giusta non basta più finché dura il ritardo.
        XCTAssertThrowsError(try lock.unlock("password-corretta-123")) { error in
            guard case AdminLock.LockError.tooManyAttempts = error else {
                return XCTFail("Atteso .tooManyAttempts, ricevuto \(error)")
            }
        }
    }

    @MainActor
    func testChangingPasswordRequiresTheCurrentOne() throws {
        let lock = makeIsolatedLock()
        try lock.setInitialPassword("password-originale-12")
        lock.lock()

        XCTAssertThrowsError(try lock.changePassword(current: "sbagliata", new: "password-nuova-1234"))

        try lock.changePassword(current: "password-originale-12", new: "password-nuova-1234")
        lock.lock()
        try lock.unlock("password-nuova-1234")
        XCTAssertTrue(lock.isUnlocked)
    }

    // MARK: - Integrazione con AppViewModel

    @MainActor
    func testCannotSetTheApiKeyWhileLocked() {
        let viewModel = makeAppViewModel()
        XCTAssertThrowsError(try viewModel.setGeminiApiKey("una-chiave-qualunque")) { error in
            guard case AppViewModel.ConfigurationError.locked = error else {
                return XCTFail("Atteso .locked, ricevuto \(error)")
            }
        }
        XCTAssertFalse(viewModel.hasGeminiApiKey)
    }

    @MainActor
    func testSettingTheApiKeyWhileUnlockedSucceeds() throws {
        let viewModel = makeAppViewModel()
        try viewModel.adminLock.setInitialPassword("password-di-prova-123")

        try viewModel.setGeminiApiKey("AIzaSyTest1234567890")

        XCTAssertTrue(viewModel.hasGeminiApiKey)
        XCTAssertEqual(viewModel.geminiApiKeyHint, "••••7890")
    }

    @MainActor
    func testLockingAgainBlocksFurtherChanges() throws {
        let viewModel = makeAppViewModel()
        try viewModel.adminLock.setInitialPassword("password-di-prova-123")
        try viewModel.setGeminiApiKey("prima-chiave")

        viewModel.adminLock.lock()

        XCTAssertThrowsError(try viewModel.setGeminiApiKey("seconda-chiave"))
        // La chiave precedente resta quella che era: un blocco fallito non
        // deve svuotarla né sostituirla in silenzio.
        XCTAssertEqual(viewModel.geminiApiKeyHint, "••••iave")
    }

    /// Il portachiavi può rifiutare la scrittura. Se succede, la chiave in
    /// memoria non deve avanzare comunque: al riavvio successivo l'app
    /// crederebbe di avere una chiave che non c'è, e la generazione
    /// fallirebbe senza nulla che punti al salvataggio andato male.
    @MainActor
    func testKeychainFailureIsReportedNotSwallowed() throws {
        // Non si può far fallire il portachiavi vero: si verifica almeno che
        // il percorso di errore esista e sia distinto da quello di blocco.
        let storage = AppViewModel.ConfigurationError.storageFailure
        let locked = AppViewModel.ConfigurationError.locked
        XCTAssertNotEqual(storage.errorDescription, locked.errorDescription)
        XCTAssertTrue(try XCTUnwrap(storage.errorDescription).contains("portachiavi"))
        XCTAssertTrue(try XCTUnwrap(storage.errorDescription).lowercased().contains("non è stata applicata"),
                      "il messaggio deve dire che la configurazione NON è stata applicata")
    }

    @MainActor
    func testEmptyKeyClearsIt() throws {
        let viewModel = makeAppViewModel()
        try viewModel.adminLock.setInitialPassword("password-di-prova-123")
        try viewModel.setGeminiApiKey("una-chiave")
        XCTAssertTrue(viewModel.hasGeminiApiKey)

        try viewModel.setGeminiApiKey("")
        XCTAssertFalse(viewModel.hasGeminiApiKey)
        XCTAssertNil(viewModel.geminiApiKeyHint)
    }

    // MARK: - Helper

    /// Ogni test usa una voce di portachiavi propria: `AdminLock` si appoggia
    /// al portachiavi reale di sistema, e senza isolarle i test si
    /// inquinerebbero a vicenda lasciando la password del test precedente.
    @MainActor
    private func makeIsolatedLock() -> AdminLock {
        KeychainStore.delete(.adminPasswordHash)
        addTeardownBlock { KeychainStore.delete(.adminPasswordHash) }
        return AdminLock()
    }

    @MainActor
    private func makeAppViewModel() -> AppViewModel {
        KeychainStore.delete(.adminPasswordHash)
        KeychainStore.delete(.geminiApiKey)
        addTeardownBlock {
            KeychainStore.delete(.adminPasswordHash)
            KeychainStore.delete(.geminiApiKey)
        }
        return AppViewModel(modelContext: .init(PersistenceController(inMemory: true).container))
    }
}
