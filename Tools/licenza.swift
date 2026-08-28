#!/usr/bin/env swift
import Foundation
import CryptoKit

// Strumento di rilascio delle licenze di HelpMe.
//
// Serve a chi vende, non a chi usa l'app. Fa due cose: genera una volta sola
// la coppia di chiavi dell'emittente, ed emette le licenze firmandole con la
// chiave privata.
//
//   swift Tools/licenza.swift genera-chiavi ~/HelpMe-chiave-privata.key
//   swift Tools/licenza.swift emetti ~/HelpMe-chiave-privata.key "I.I.S. Antonio Della Lucia" 2027-08-31
//   swift Tools/licenza.swift leggi <codice-licenza>
//
// La firma e' ECDSA P-256 con SHA-256, e la chiave pubblica e' la forma
// grezza X||Y di 64 byte: e' cio' che sia CryptoKit sia .NET sanno leggere
// senza librerie aggiuntive, cosi' la stessa licenza vale su Mac e su PC.
//
// La chiave privata non va nel repository, non va in un backup condiviso e
// non va inviata per email. Chi ce l'ha puo' emettere licenze a nome tuo, e
// non c'e' modo di revocarle: l'app verifica senza rete, quindi non puo'
// sapere che una licenza e' stata ritirata. Se la perdi, si genera una coppia
// nuova e si ricompila l'app; le licenze vecchie smettono di valere tutte
// insieme, comprese quelle delle scuole che hanno pagato.

extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL string: String) {
        var s = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        guard let d = Data(base64Encoded: s) else { return nil }
        self = d
    }
}

func esci(_ messaggio: String) -> Never {
    FileHandle.standardError.write(Data((messaggio + "\n").utf8))
    exit(1)
}

let uso = """
Uso:
  licenza.swift genera-chiavi <percorso-chiave-privata>
  licenza.swift emetti <percorso-chiave-privata> "<Nome scuola>" <AAAA-MM-GG>
  licenza.swift leggi <codice-licenza>
"""

let argomenti = Array(CommandLine.arguments.dropFirst())
guard let comando = argomenti.first else { esci(uso) }

let giorno: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Rome")
    return f
}()

switch comando {

case "genera-chiavi":
    guard argomenti.count == 2 else { esci(uso) }
    let percorso = (argomenti[1] as NSString).expandingTildeInPath

    if FileManager.default.fileExists(atPath: percorso) {
        esci("""
        Esiste gia' un file in \(percorso).
        Non lo sovrascrivo: se e' la chiave in uso, sovrascriverla invaliderebbe
        tutte le licenze gia' emesse. Spostalo a mano se sei sicuro.
        """)
    }

    let privata = P256.Signing.PrivateKey()
    let dati = Data(privata.rawRepresentation.base64EncodedString().utf8)
    // Leggibile solo dall'utente: e' l'unica copia che esiste.
    guard FileManager.default.createFile(
        atPath: percorso,
        contents: dati,
        attributes: [.posixPermissions: 0o600]
    ) else { esci("Non sono riuscito a scrivere \(percorso)") }

    print("""
    Chiave privata scritta in \(percorso) (permessi 600).
    Conservala dove conservi le cose che non si possono rifare: se la perdi,
    le licenze gia' emesse non si possono piu' rinnovare con la stessa app.

    Ora incolla questa chiave pubblica in
    Helpme/Services/Licensing/License.swift, alla costante issuerPublicKey:

        public static let issuerPublicKey = "\(privata.publicKey.rawRepresentation.base64EncodedString())"

    Finche' quella costante resta vuota, l'app non applica nessuna licenza.
    """)

case "emetti":
    guard argomenti.count == 4 else { esci(uso) }
    let percorso = (argomenti[1] as NSString).expandingTildeInPath
    let scuola = argomenti[2]

    // La scadenza indicata e' l'ultimo giorno compreso, quindi si firma la
    // sua fine e non il suo inizio: una licenza al 31 agosto copre il 31
    // agosto per intero. Scrivendo qui l'istante esatto, l'app deve solo
    // confrontare due date e non ricostruire il giorno con il fuso di chi
    // sta usando il Mac.
    guard let mezzanotte = giorno.date(from: argomenti[3]) else {
        esci("Data non valida: \(argomenti[3]). Attesa nel formato AAAA-MM-GG, per esempio 2027-08-31.")
    }
    let scadenza = mezzanotte.addingTimeInterval(24 * 60 * 60 - 1)
    if scadenza < Date() {
        esci("La scadenza \(argomenti[3]) e' gia' passata: emetteresti una licenza nata scaduta.")
    }
    guard !scuola.trimmingCharacters(in: .whitespaces).isEmpty else {
        esci("L'intestatario non puo' essere vuoto: e' il nome che comparira' nell'app.")
    }

    guard let testo = try? String(contentsOfFile: percorso, encoding: .utf8),
          let grezza = Data(base64Encoded: testo.trimmingCharacters(in: .whitespacesAndNewlines)),
          let privata = try? P256.Signing.PrivateKey(rawRepresentation: grezza)
    else { esci("Non riesco a leggere una chiave privata da \(percorso)") }

    let payload: [String: String] = [
        "scuola": scuola,
        "emessa": ISO8601DateFormatter().string(from: Date()),
        "scade": ISO8601DateFormatter().string(from: scadenza)
    ]
    guard let dati = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
          let firma = try? privata.signature(for: dati).rawRepresentation
    else { esci("Firma non riuscita.") }

    print("""

    Licenza per \(scuola), valida fino al \(argomenti[3]) compreso.
    Da incollare nelle impostazioni dell'app, alla voce Licenza:

    \(dati.base64URL).\(firma.base64URL)
    """)

case "leggi":
    guard argomenti.count == 2 else { esci(uso) }
    let parti = argomenti[1].split(separator: ".")
    guard parti.count == 2, let payload = Data(base64URL: String(parti[0])),
          let campi = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
    else { esci("Non e' un codice licenza leggibile.") }

    // Non verifica la firma: serve solo a rileggere cosa si e' emesso.
    print("Intestatario: \(campi["scuola"] ?? "?")")
    print("Emessa:       \(campi["emessa"] ?? "?")")
    print("Scade:        \(campi["scade"] ?? "?")")
    print("\n(La firma non e' stata verificata: per quello serve l'app.)")

default:
    esci(uso)
}
