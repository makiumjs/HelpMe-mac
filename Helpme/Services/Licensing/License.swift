import Foundation
import CryptoKit
public nonisolated struct License: Equatable, Codable, Sendable {
    public let school: String
    public let expiresOn: Date
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
public enum LicenseState: Equatable, Sendable {
    case notEnforced
    case valid(License)
    case expired(License)
    case missing
    case invalid(reason: String)
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
    public var isHealthy: Bool {
        switch self {
        case .notEnforced, .valid: return true
        case .expired, .missing, .invalid: return false
        }
    }
}
nonisolated public enum LicenseVerifier {
    public static let issuerPublicKey = ""

    public static var isEnforced: Bool { !issuerPublicKey.isEmpty }
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
        return now < license.expiresOn ? .valid(license) : .expired(license)
    }
}
nonisolated public enum LicenseGate {

    public static func canGenerate(_ state: LicenseState) -> Bool {
        switch state {
        case .notEnforced, .valid: return true
        case .expired, .missing, .invalid: return false
        }
    }
    public static func canRead(_ state: LicenseState) -> Bool { true }
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

nonisolated extension DateFormatter {
    /// Si costruisce a ogni chiamata invece di stare in una costante statica:
    /// `DateFormatter` non e' `Sendable`, e la licenza si legge anche fuori
    /// dal main actor. Formattare una scadenza succede una volta ogni tanto.
    static var italianDay: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = TimeZone(identifier: "Europe/Rome")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }
}

nonisolated extension Data {
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
