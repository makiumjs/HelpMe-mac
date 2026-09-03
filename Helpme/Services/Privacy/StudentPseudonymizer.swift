import Foundation
nonisolated public enum StudentPseudonymizer {
    private static let clinicalTerms: [String] = [
        "dsa", "dislessi", "discalculi", "disgrafi", "disortografi",
        "adhd", "autism", "asperger", "disprassi", "afasi",
        "disabilit", "handicap", "ritardo", "deficit", "disturb",
        "diagnos", "certificat", "certificazion", "neuropsichiatr", "logopedi",
        "l 104", "legge 104", "104 1992", "170 2010",
        "qi", "wisc", "icf", "pei", "pdp"
    ]
    public static func generalizeClass(_ classInfo: String) -> String {
        let trimmed = classInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "scuola secondaria di II grado" }
        let year = trimmed.first(where: { $0.isNumber }).map(String.init)
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
    public static func filterClinicalReferences(from notes: String) -> String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let didacticOnly = splitIntoSentences(trimmed).filter { !containsClinicalTerm($0) }
        let result = didacticOnly.joined(separator: ". ")
        return containsClinicalTerm(result) ? "" : result
    }
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
    static func containsClinicalTerm(_ text: String) -> Bool {
        !clinicalTerms(in: text).isEmpty
    }

    public static func clinicalTerms(in text: String) -> [String] {
        let haystack = " " + normalizeForMatching(text) + " "
        return clinicalTerms.filter { haystack.contains(" " + normalizeForMatching($0)) }
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
}
