import Foundation
import CryptoKit

/// Una licenza d'uso intestata a una scuola.
///
/// È un foglietto firmato, non un lucchetto: contiene a chi è intestata e
/// fino a quando vale, e porta la firma di chi la emette. Si verifica senza
/// rete — sulla rete di una scuola un controllo online è un punto di rottura
/// in più, e contraddirebbe la promessa che questa app non parla con nessuno
/// se non glielo si chiede.
public struct License: Equatable, Codable, Sendable {
    /// Intestatario, come va scritto in fattura.
    public let school: String
    /// Ultimo giorno di validità compreso.
    public let expiresOn: Date
    /// Data di emissione, utile solo a leggere il foglietto.
    public let issuedOn: Date

    public init(school: String, issuedOn: Date, expiresOn: Date) {
        self.school = school
        self.issuedOn = issuedOn
        self.expiresOn = expiresOn
    }

    enum CodingKeys: String, CodingKey {
        case school = "scuola"
        case issuedOn = "emessa"
        case expiresOn = "scade"
    }
}

/// In che rapporto è l'installazione con la sua licenza.
public enum LicenseState: Equatable, Sendable {
    /// Nessuna chiave pubblica compilata nell'app: le licenze non sono
    /// applicate. È lo stato delle copie di sviluppo.
    case notEnforced
    /// Licenza valida fino alla data indicata.
    case valid(License)
    /// Licenza autentica ma scaduta.
    case expired(License)
    /// Nessuna licenza installata su questa macchina.
    case missing
    /// C'è un file, ma non regge la verifica: manomesso, troncato, o emesso
    /// con una chiave diversa da quella di questa app.
    case invalid(reason: String)

    /// Riga di stato da mostrare nelle impostazioni, leggibile anche da chi
    /// non ha la password amministratore: sapere che la licenza è scaduta
    /// serve al docente tanto quanto a chi l'ha installata.
    public var summary: String {
        switch self {
        case .notEnforced:
            return "Copia non vincolata a licenza."
        case .valid(let license):
            return "Licenza attiva — \(license.school), fino al \(DateFormatter.italianDay.string(from: license.expiresOn)) compreso."
        case .expired(let license):
            return "Licenza scaduta il \(DateFormatter.italianDay.string(from: license.expiresOn)) — \(license.school)."
        case .missing:
            return "Nessuna licenza installata su questa postazione."
        case .invalid(let reason):
            return reason
        }
    }

    /// Come colorare la riga di stato.
    public var isHealthy: Bool {
        switch self {
        case .notEnforced, .valid: return true
        case .expired, .missing, .invalid: return false
        }
    }
}

/// Verifica le licenze contro la chiave pubblica di chi le emette.
///
/// La chiave privata corrispondente non sta in questo repository e non deve
/// starci mai: senza quella, una licenza non si può fabbricare. Quella
/// pubblica qui sotto è pubblica per costruzione — serve solo a controllare
/// una firma, non a produrla.
nonisolated public enum LicenseVerifier {

    /// Chiave pubblica ECDSA P-256 dell'emittente, in base64 (64 byte: X||Y).
    ///
    /// P-256 e non Ed25519 per una ragione sola, ma vincolante: la stessa
    /// licenza deve valere sul Mac e sul PC di una scuola che ne compra una,
    /// e .NET 8 — su cui gira la controparte Windows — non espone Ed25519.
    /// Implementarlo là vorrebbe dire aggiungere una libreria di crittografia
    /// di terze parti a un progetto che ne ha già rifiutata una per sospetto
    /// hijacking del pacchetto. P-256 è di prima parte su entrambi.
    ///
    /// Vuota finché non si genera la coppia con `Tools/licenza.swift`. Finché
    /// è vuota l'app non applica nessuna licenza: si preferisce una copia di
    /// sviluppo che funziona a una che si blocca da sola perché qualcuno ha
    /// dimenticato un passaggio.
    public static let issuerPublicKey = ""

    public static var isEnforced: Bool { !issuerPublicKey.isEmpty }

    /// Formato del foglietto: `payload.firma`, entrambi in base64url, così
    /// sta in una riga di email e si incolla senza che nulla lo rovini.
    public static func verify(
        token: String,
        publicKey: String = issuerPublicKey,
        now: Date = Date()
    ) -> LicenseState {
        guard !publicKey.isEmpty else { return .notEnforced }

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .missing }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let payload = Data(base64URLEncoded: String(parts[0])),
              let signature = Data(base64URLEncoded: String(parts[1]))
        else { return .invalid(reason: "Il codice licenza non è nel formato atteso.") }

        guard let keyData = Data(base64Encoded: publicKey),
              let key = try? P256.Signing.PublicKey(rawRepresentation: keyData)
        else { return .invalid(reason: "Questa copia dell'app non ha una chiave di verifica valida.") }

        // Firma grezza r||s di 64 byte: è la forma che .NET produce come
        // IeeeP1363FixedFieldConcatenation, così le due implementazioni si
        // leggono a vicenda senza conversioni.
        guard let ecdsaSignature = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
            return .invalid(reason: "La firma della licenza non è nel formato atteso.")
        }

        guard key.isValidSignature(ecdsaSignature, for: payload) else {
            return .invalid(reason: "La firma non corrisponde: la licenza è stata modificata, oppure non è stata emessa per questa versione dell'app.")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let license = try? decoder.decode(License.self, from: payload) else {
            return .invalid(reason: "La licenza è firmata ma illeggibile.")
        }

        // `expiresOn` è già l'ultimo istante utile: lo scrive così chi emette
        // la licenza, che sa a quale giorno si riferisce. Qui si confrontano
        // due istanti e basta, senza ricostruire il giorno con il fuso orario
        // del Mac su cui l'app sta girando.
        return now < license.expiresOn ? .valid(license) : .expired(license)
    }
}

/// Cosa resta possibile in ciascuno stato.
///
/// La regola che conta: **una licenza scaduta ferma la generazione, mai la
/// lettura.** Il materiale già prodotto è dello studente che lo sta usando, e
/// nessuna questione amministrativa deve fargli trovare lo schermo bloccato a
/// metà di una scheda. Chi deve rinnovare è la scuola, e la scuola la avvisa
/// il docente, non l'alunno.
nonisolated public enum LicenseGate {

    public static func canGenerate(_ state: LicenseState) -> Bool {
        switch state {
        case .notEnforced, .valid: return true
        case .expired, .missing, .invalid: return false
        }
    }

    /// Sempre vero. Esiste come funzione, e non come costante sottintesa,
    /// perché la regola sia scritta da qualche parte e un test la presidi.
    public static func canRead(_ state: LicenseState) -> Bool { true }

    /// Il messaggio da mostrare al docente quando non può generare.
    public static func explanation(_ state: LicenseState) -> String? {
        switch state {
        case .notEnforced, .valid:
            return nil
        case .expired(let license):
            let giorno = DateFormatter.italianDay.string(from: license.expiresOn)
            return "La licenza di \(license.school) è scaduta il \(giorno). "
                 + "Il materiale già prodotto resta leggibile e lo studente può continuare a usarlo; "
                 + "per generarne di nuovo serve il rinnovo."
        case .missing:
            return "Questa copia di HelpMe non è ancora attivata. Inserisci il codice licenza nelle impostazioni."
        case .invalid(let reason):
            return reason
        }
    }
}

extension DateFormatter {
    static let italianDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        // Fuso fissato su Roma: la scadenza è l'ultimo istante di un giorno
        // italiano, e su un Mac impostato altrove verrebbe mostrato il giorno
        // dopo.
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()
}

extension Data {
    /// base64url: senza padding e senza i caratteri che email e URL rovinano.
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64) else { return nil }
        self = data
    }

    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
