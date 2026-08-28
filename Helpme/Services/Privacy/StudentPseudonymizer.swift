import Foundation

/// Prepara i dati dell'alunno per l'invio a un servizio cloud.
///
/// Nome e riferimenti diagnostici sono dati personali e sanitari di un minore
/// e non escono dal dispositivo: nel prompt viaggia il segnaposto `[ALUNNO]`,
/// che `restoreIdentity(in:)` rimpiazza col nome vero una volta tornata la
/// risposta. Restano invece nel prompt gli elementi che servono davvero alla
/// didattica — anno di corso, indirizzo, percorso PEI, interessi, misure
/// compensative — perché non identificano la persona.
public enum StudentPseudonymizer {

    /// Segnaposto usato nel prompt al posto del nome.
    public static let placeholder = "[ALUNNO]"

    /// Termini che segnalano una diagnosi o una certificazione clinica.
    /// Le frasi che li contengono non vengono inviate al cloud.
    ///
    /// Il confronto passa da `normalizeForMatching`, quindi la punteggiatura
    /// qui è indifferente ("l. 104" e "l 104" sono lo stesso termine) e non
    /// servono spazi finali per evitare i falsi positivi: ci pensa il
    /// confine di parola.
    private static let clinicalTerms: [String] = [
        "dsa", "dislessi", "discalculi", "disgrafi", "disortografi",
        "adhd", "autism", "asperger", "disprassi", "afasi",
        "disabilit", "handicap", "ritardo", "deficit", "disturb",
        "diagnos", "certificat", "certificazion", "neuropsichiatr", "logopedi",
        "l 104", "legge 104", "104 1992", "170 2010",
        "qi", "wisc", "icf", "pei", "pdp"
    ]

    /// Anno di corso e indirizzo, senza la sezione: "3ª A Agrario" → "3º anno, indirizzo Agrario".
    /// La sezione, unita al nome dell'istituto, restringerebbe troppo il campo.
    public static func generalizeClass(_ classInfo: String) -> String {
        let trimmed = classInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "scuola secondaria di II grado" }

        // Primo numero presente = anno di corso.
        let year = trimmed.first(where: { $0.isNumber }).map(String.init)

        // Rimuove anno e sezione (lettera isolata) per tenere solo l'indirizzo.
        let words = trimmed
            .components(separatedBy: .whitespaces)
            .filter { word in
                let clean = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                if clean.isEmpty { return false }
                if clean.count == 1 { return false }              // sezione: "A", "B"
                if clean.allSatisfy({ $0.isNumber }) { return false }
                if clean.first?.isNumber == true { return false }  // "3ª"
                return true
            }

        let track = words.joined(separator: " ")

        switch (year, track.isEmpty) {
        case let (y?, false): return "\(y)º anno, indirizzo \(track)"
        case let (y?, true):  return "\(y)º anno di scuola secondaria di II grado"
        case (nil, false):    return "indirizzo \(track)"
        case (nil, true):     return "scuola secondaria di II grado"
        }
    }

    /// Rimuove dalle note le frasi che contengono riferimenti diagnostici,
    /// conservando le osservazioni didattiche.
    ///
    /// Il rischio non è simmetrico: scartare un'osservazione didattica di
    /// troppo rende il materiale un po' meno personalizzato, lasciar passare
    /// un riferimento clinico manda il dato sanitario di un minore a un
    /// servizio cloud. A parità di dubbio si scarta.
    public static func filterClinicalReferences(from notes: String) -> String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let didacticOnly = splitIntoSentences(trimmed).filter { !containsClinicalTerm($0) }
        let result = didacticOnly.joined(separator: ". ")

        // Rete di sicurezza: se dopo il filtro per frasi resta comunque un
        // riferimento clinico — perché la segmentazione ha diviso il termine
        // a metà, o per una forma non prevista — si scarta tutto. Meglio
        // "osservazioni non specificate" che una diagnosi spedita a Google.
        return containsClinicalTerm(result) ? "" : result
    }

    /// Divide in frasi su `;` e a capo, e sul punto **solo quando è una vera
    /// fine di frase** (seguito da spazio e maiuscola, o da fine testo).
    ///
    /// Spezzare su ogni punto rompeva a metà proprio i riferimenti da
    /// intercettare: "L. 104" diventava "L" + "104", e nessuno dei due pezzi
    /// somigliava più a un termine della lista.
    static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let characters = Array(text)

        for (index, character) in characters.enumerated() {
            if character == ";" || character.isNewline {
                sentences.append(current)
                current = ""
                continue
            }

            if character == "." {
                let rest = characters[(index + 1)...]
                let nextVisible = rest.first(where: { !$0.isWhitespace })
                let endsHere = nextVisible == nil
                let startsNewSentence = nextVisible?.isUppercase == true

                if endsHere || startsNewSentence {
                    sentences.append(current)
                    current = ""
                    continue
                }
            }

            current.append(character)
        }
        sentences.append(current)

        return sentences
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Vero se il testo contiene un riferimento clinico.
    ///
    /// Il confronto avviene su una forma normalizzata — minuscolo, ogni
    /// segno non alfanumerico ridotto a spazio — così "L. 104", "L.104" e
    /// "l 104" collassano tutti su "l 104". Il termine deve iniziare a
    /// confine di parola: senza, "icf" scatterebbe dentro "pacifico" e "qi"
    /// dentro parole che lo contengono per caso.
    static func containsClinicalTerm(_ text: String) -> Bool {
        let haystack = " " + normalizeForMatching(text) + " "
        return clinicalTerms.contains { term in
            haystack.contains(" " + normalizeForMatching(term))
        }
    }

    private static func normalizeForMatching(_ text: String) -> String {
        let flattened = text.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(flattened)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Blocco "dati alunno" da inserire nel prompt, privo di elementi identificativi.
    public static func promptProfile(for student: StudentProfile) -> String {
        let didacticNotes = filterClinicalReferences(from: student.notes)
        let notesLine = didacticNotes.isEmpty
            ? "- Osservazioni didattiche: non specificate."
            : "- Osservazioni didattiche: \(didacticNotes)."

        return """
        DATI ALUNNO (anonimizzati — riferisciti allo studente con il segnaposto \(placeholder)):
        - Riferimento: \(placeholder)
        - Livello scolastico: \(generalizeClass(student.classInfo))
        - Tipologia percorso: \(student.programType.localizedTitle) (\(student.programType.legalReference))
        - Interesse per analogie ed esempi: \(student.interest)
        \(notesLine)
        - Misure compensative attive: \(student.compensatoryMeasures.joined(separator: ", "))
        - Misure dispensative: \(student.dispensatoryMeasures.joined(separator: ", "))
        """
    }

    /// Reinserisce il nome vero nel testo tornato dal cloud.
    public static func restoreIdentity(in text: String, name: String) -> String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return text }
        return text.replacingOccurrences(of: placeholder, with: cleanName)
    }
}
