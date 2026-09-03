import XCTest
import CryptoKit
import SwiftData
@testable import Helpme

/// La licenza è l'unica parte dell'app che deve resistere a qualcuno che
/// prova a imbrogliarla. Questi test emettono licenze con una coppia di
/// chiavi usa-e-getta e provano a falsificarle nei modi ovvi.
final class LicenseTests: XCTestCase {

    private let issuer = P256.Signing.PrivateKey()

    private var publicKey: String { issuer.publicKey.rawRepresentation.base64EncodedString() }

    /// Emette una licenza vera, firmata come farebbe lo strumento di rilascio.
    private func makeToken(
        school: String = "I.I.S. Antonio Della Lucia",
        expiresOn: Date,
        signedBy signer: P256.Signing.PrivateKey? = nil
    ) throws -> String {
        let license = License(school: school, issuedOn: Date(), expiresOn: expiresOn)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payload = try encoder.encode(license)
        let signature = try (signer ?? issuer).signature(for: payload).rawRepresentation
        return "\(payload.base64URLEncodedString).\(signature.base64URLEncodedString)"
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    /// L'ultimo istante di un giorno italiano, come lo scrive `Tools/licenza.swift`
    /// quando gli si chiede una licenza "fino al" quel giorno.
    private func endOfDay(_ date: Date) -> Date {
        var rome = Calendar(identifier: .gregorian)
        rome.timeZone = TimeZone(identifier: "Europe/Rome")!
        return rome.startOfDay(for: date).addingTimeInterval(24 * 60 * 60 - 1)
    }

    // MARK: - Il caso normale

    func testAValidLicenseNamesTheSchoolAndLetsTheTeacherGenerate() throws {
        let token = try makeToken(expiresOn: day(30))

        let state = LicenseVerifier.verify(token: token, publicKey: publicKey)

        guard case .valid(let license) = state else { return XCTFail("Attesa valida, ottenuto \(state)") }
        XCTAssertEqual(license.school, "I.I.S. Antonio Della Lucia")
        XCTAssertTrue(LicenseGate.canGenerate(state))
        XCTAssertNil(LicenseGate.explanation(state))
    }

    /// Una licenza che scade oggi copre tutto oggi. Se scadesse a mezzanotte
    /// del giorno prima, l'ultimo giorno pagato non si potrebbe lavorare.
    func testALicenseExpiringTodayStillWorksToday() throws {
        let token = try makeToken(expiresOn: endOfDay(Date()))

        let state = LicenseVerifier.verify(token: token, publicKey: publicKey)

        XCTAssertTrue(LicenseGate.canGenerate(state), "L'ultimo giorno di validità va usato per intero: \(state)")
    }

    /// Il giorno dopo la scadenza non deve piu' passare, nemmeno di poco.
    func testTheDayAfterExpiryTheLicenseIsOver() throws {
        let token = try makeToken(expiresOn: endOfDay(day(-1)))

        let state = LicenseVerifier.verify(token: token, publicKey: publicKey)

        guard case .expired = state else { return XCTFail("Attesa scaduta, ottenuto \(state)") }
    }

    // MARK: - Scadenza

    func testAnExpiredLicenseStopsGenerationButNeverReading() throws {
        let token = try makeToken(expiresOn: day(-1))

        let state = LicenseVerifier.verify(token: token, publicKey: publicKey)

        guard case .expired = state else { return XCTFail("Attesa scaduta, ottenuto \(state)") }
        XCTAssertFalse(LicenseGate.canGenerate(state))
        XCTAssertTrue(LicenseGate.canRead(state),
                      "Uno studente non deve trovarsi la scheda bloccata per una scadenza amministrativa.")
    }

    func testTheExpiryMessageSaysWhatStillWorks() throws {
        let token = try makeToken(expiresOn: day(-1))

        let state = LicenseVerifier.verify(token: token, publicKey: publicKey)
        let message = try XCTUnwrap(LicenseGate.explanation(state))

        XCTAssertTrue(message.contains("I.I.S. Antonio Della Lucia"), message)
        XCTAssertTrue(message.contains("resta leggibile"),
                      "Va detto subito che il materiale dello studente non sparisce: \(message)")
    }

    /// La lettura non si ferma in nessuno stato, nemmeno senza licenza.
    func testReadingIsNeverBlockedInAnyState() throws {
        let states: [LicenseState] = [
            .notEnforced,
            .missing,
            .invalid(reason: "qualunque"),
            .expired(License(school: "X", issuedOn: day(-400), expiresOn: day(-1))),
            .valid(License(school: "X", issuedOn: day(-1), expiresOn: day(1)))
        ]

        for state in states {
            XCTAssertTrue(LicenseGate.canRead(state), "Lettura bloccata in \(state)")
        }
    }

    // MARK: - Tentativi di imbroglio

    func testALicenseSignedBySomeoneElseIsRejected() throws {
        let impostor = P256.Signing.PrivateKey()
        let token = try makeToken(expiresOn: day(30), signedBy: impostor)

        let state = LicenseVerifier.verify(token: token, publicKey: publicKey)

        guard case .invalid = state else { return XCTFail("Una firma estranea deve cadere: \(state)") }
        XCTAssertFalse(LicenseGate.canGenerate(state))
    }

    /// Il caso concreto: qualcuno apre il foglietto, sposta la scadenza in
    /// avanti e lo rimette dentro senza toccare la firma.
    func testMovingTheExpiryDateForwardBreaksTheSignature() throws {
        let token = try makeToken(expiresOn: day(-1))
        let parts = token.split(separator: ".")
        let payload = try XCTUnwrap(Data(base64URLEncoded: String(parts[0])))

        // Si riapre il foglietto, si sposta la scadenza di un anno in avanti
        // e si rimette la firma originale così com'era.
        var fields = try XCTUnwrap(
            JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        fields["scade"] = ISO8601DateFormatter().string(from: day(365))
        let tampered = try JSONSerialization.data(withJSONObject: fields)
        XCTAssertNotEqual(tampered, payload, "La falsificazione non ha cambiato niente: il test non proverebbe nulla.")

        let forged = "\(tampered.base64URLEncodedString).\(parts[1])"
        let state = LicenseVerifier.verify(token: forged, publicKey: publicKey)

        guard case .invalid = state else {
            return XCTFail("Scadenza spostata a mano e firma non ricontrollata: \(state)")
        }
        XCTAssertFalse(LicenseGate.canGenerate(state))
    }

    func testGarbageAndEmptyTokensAreToldApart() {
        XCTAssertEqual(LicenseVerifier.verify(token: "", publicKey: publicKey), .missing)
        XCTAssertEqual(LicenseVerifier.verify(token: "   \n ", publicKey: publicKey), .missing)

        guard case .invalid = LicenseVerifier.verify(token: "non-una-licenza", publicKey: publicKey) else {
            return XCTFail("Un codice storto va segnalato come storto, non come assente.")
        }
    }

    func testATruncatedTokenIsRejected() throws {
        let token = try makeToken(expiresOn: day(30))
        let truncated = String(token.dropLast(8))

        let state = LicenseVerifier.verify(token: truncated, publicKey: publicKey)

        XCTAssertFalse(LicenseGate.canGenerate(state), "Un codice troncato non deve passare: \(state)")
    }

    // MARK: - Accordo con lo strumento di rilascio

    /// Licenza emessa davvero da `Tools/licenza.swift`, con una coppia di
    /// chiavi usa-e-getta, e incollata qui com'è uscita.
    ///
    /// Serve a tenere insieme le due metà: lo strumento firma un JSON, l'app
    /// lo rilegge. Se qualcuno cambia il nome di un campo, il formato di una
    /// data o l'ordine delle chiavi in uno dei due posti soltanto, tutte le
    /// licenze già vendute smettono di funzionare — e senza questo test lo si
    /// scoprirebbe da una telefonata della scuola.
    ///
    /// Questo stesso codice è stato verificato anche da .NET 8 (ECDsa P-256,
    /// `IeeeP1363FixedFieldConcatenation`): la controparte Windows deve
    /// accettare le licenze emesse qui, perché la scuola ne compra una sola.
    func testALicenseIssuedByTheRealToolIsAccepted() throws {
        let issuedKey = "yi/Bm6rQnnlBIhYaZOj2g0e3Fc8TnDTkR5b4U+u6Z8F9hTaHBc2HycILCvlEYu0GQBtJHNfN0VgsqPPfvu7jEQ=="
        let issuedToken = "eyJlbWVzc2EiOiIyMDI2LTA4LTI4VDIyOjU0OjAzWiIsInNjYWRlIjoiMjA5OS0xMi0zMVQyMjo1OTo1OVoiLCJzY3VvbGEiOiJJLkkuUy4gQW50b25pbyBEZWxsYSBMdWNpYSJ9.V1kmUL-FYWKVyXcnHg1yG20UTNSqAQ1Vt9-rGXdkSm7VtW0FEPgXUCPV5n3Y9X2b9jV2mLfycPHISzpuQPQ3hQ"

        let state = LicenseVerifier.verify(token: issuedToken, publicKey: issuedKey)

        guard case .valid(let license) = state else {
            return XCTFail("L'app non riconosce più le licenze del suo strumento: \(state)")
        }
        XCTAssertEqual(license.school, "I.I.S. Antonio Della Lucia")
        XCTAssertEqual(DateFormatter.italianDay.string(from: license.expiresOn), "31 dicembre 2099",
                       "La scadenza va mostrata come l'ultimo giorno compreso.")
    }

    // MARK: - Copie di sviluppo

    /// Senza chiave pubblica compilata l'app non applica licenze. Meglio una
    /// copia di sviluppo che funziona di una che si blocca da sola.
    func testWithoutAnIssuerKeyNothingIsEnforced() throws {
        let token = try makeToken(expiresOn: day(-1))

        let state = LicenseVerifier.verify(token: token, publicKey: "")

        XCTAssertEqual(state, .notEnforced)
        XCTAssertTrue(LicenseGate.canGenerate(state))
    }

    /// Guardia sul rilascio: quando arriva il momento di vendere, questa
    /// costante va riempita. Il test dice quale delle due situazioni è.
    func testTheShippedKeyStateIsExplicit() {
        if LicenseVerifier.issuerPublicKey.isEmpty {
            XCTAssertFalse(LicenseVerifier.isEnforced,
                           "Chiave vuota ma licenze applicate: l'app si bloccherebbe da sola.")
        } else {
            XCTAssertNotNil(Data(base64Encoded: LicenseVerifier.issuerPublicKey),
                            "La chiave compilata non è base64 valido.")
            XCTAssertTrue(LicenseVerifier.isEnforced)
        }
    }

    // MARK: - Effetto sull'app

    @MainActor
    func testAnExpiredLicenseStopsGenerationAndSaysSoInsteadOfTalkingAboutTheFormat() async throws {
        let viewModel = AppViewModel(modelContext: try makeContext())
        viewModel.licenseState = .expired(License(school: "I.I.S. Della Lucia", issuedOn: day(-400), expiresOn: day(-1)))
        viewModel.addStudent(StudentProfile(name: "Paolo Gialli", classInfo: "3ª B"))
        viewModel.sourceText = "Il ciclo Otto a quattro tempi."

        XCTAssertFalse(viewModel.canGenerate)
        let rationale = try XCTUnwrap(viewModel.formatRationale)
        XCTAssertTrue(rationale.contains("scaduta"),
                      "Con la licenza scaduta il docente deve leggere di quello, non del formato: \(rationale)")

        await viewModel.generateMaterial()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.generatedContent.isEmpty, "Non si genera niente senza licenza valida.")
    }

    /// Un codice storto non deve cancellare la licenza buona che c'era.
    @MainActor
    func testAnInvalidTokenDoesNotOverwriteWhatWasAlreadyThere() throws {
        SettingsStore.save(licenseToken: "licenza.buona")
        let viewModel = AppViewModel(modelContext: try makeContext())

        viewModel.activate(licenseToken: "spazzatura")

        XCTAssertEqual(SettingsStore.loadLicenseToken(), "licenza.buona")
        SettingsStore.save(licenseToken: nil)
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - Persistenza

    func testSavingAndClearingTheToken() {
        SettingsStore.save(licenseToken: "  abc.def  ")
        XCTAssertEqual(SettingsStore.loadLicenseToken(), "abc.def", "Gli spazi di un copia-incolla vanno tolti.")

        SettingsStore.save(licenseToken: "   ")
        XCTAssertNil(SettingsStore.loadLicenseToken(), "Un codice vuoto equivale a nessun codice.")
    }
}
