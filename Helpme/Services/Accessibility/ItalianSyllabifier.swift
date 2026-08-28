import Foundation

/// Divisione in sillabe dell'italiano, per la lettura a colori alternati.
///
/// Applica le regole scolastiche standard. Non è un algoritmo linguistico
/// completo — nessuno lo è senza un dizionario — ma copre i casi che contano
/// per chi sta imparando a decodificare le parole lunghe.
nonisolated enum ItalianSyllabifier {

    private static let vowels = Set("aeiouàèéìòóùAEIOUÀÈÉÌÒÓÙ")

    /// Gruppi che non si separano mai perché iniziano una sillaba.
    private static let inseparableClusters: Set<String> = [
        "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl", "pr",
        "tr", "vr", "sb", "sc", "sd", "sf", "sg", "sl", "sm", "sn", "sp",
        "sq", "sr", "st", "sv", "gn", "ch", "gh", "qu", "sch"
    ]

    /// Digrammi che valgono come un suono solo.
    private static let digraphs: Set<String> = ["ch", "gh", "gn", "gl", "sc", "qu"]

    private static func isVowel(_ character: Character) -> Bool {
        vowels.contains(character)
    }

    /// Ultima divisione calcolata.
    ///
    /// La vista di lettura richiama `syllabify` sull'intero documento a ogni
    /// ridisegno — per esempio a ogni fotogramma mentre si trascina il
    /// cursore della dimensione del carattere — e il testo in quei casi non
    /// è cambiato. Ricordare l'ultimo risultato basta a coprire tutti questi
    /// casi, perché in lettura il documento è uno solo.
    private static let memo = Memo()

    private final class Memo: @unchecked Sendable {
        private let lock = NSLock()
        private var input: String?
        private var output: [String] = []

        func value(for text: String, compute: (String) -> [String]) -> [String] {
            lock.lock()
            if input == text {
                defer { lock.unlock() }
                return output
            }
            lock.unlock()

            // Il calcolo sta fuori dal lock: è la parte lenta, e bloccarci
            // sopra serializzerebbe chiamate su testi diversi senza motivo.
            let computed = compute(text)

            lock.lock()
            input = text
            output = computed
            lock.unlock()

            return computed
        }
    }

    /// Divide il testo mantenendo spazi e punteggiatura come frammenti a sé.
    static func syllabify(_ text: String) -> [String] {
        memo.value(for: text, compute: syllabifyUncached)
    }

    private static func syllabifyUncached(_ text: String) -> [String] {
        var output: [String] = []
        var word = ""

        func flushWord() {
            guard !word.isEmpty else { return }
            output.append(contentsOf: syllabifyWord(word))
            word = ""
        }

        for character in text {
            if character.isLetter {
                word.append(character)
            } else {
                flushWord()
                output.append(String(character))
            }
        }
        flushWord()
        return output
    }

    /// Divide una singola parola.
    static func syllabifyWord(_ word: String) -> [String] {
        let characters = Array(word)
        guard characters.count > 3 else { return [word] }

        var syllables: [String] = []
        var current = ""
        var i = 0

        while i < characters.count {
            let character = characters[i]
            current.append(character)

            guard i + 1 < characters.count else { break }

            let next = characters[i + 1]

            if isVowel(character) {
                if isVowel(next) {
                    // Dittongo o iato: non si spezza, per non confondere chi legge.
                    i += 1
                    continue
                }

                // Consonante dopo vocale: si decide guardando cosa la segue.
                let following = i + 2 < characters.count ? characters[i + 2] : nil

                if let following {
                    if isVowel(following) {
                        // V-CV: la consonante apre la sillaba successiva.
                        syllables.append(current)
                        current = ""
                    } else {
                        let cluster = String([next, following]).lowercased()
                        let isDoubleConsonant = next.lowercased() == following.lowercased()

                        if isDoubleConsonant {
                            // Doppia: la prima chiude, la seconda apre.
                            current.append(next)
                            syllables.append(current)
                            current = ""
                            i += 1
                        } else if inseparableClusters.contains(cluster) || digraphs.contains(cluster) {
                            // Il gruppo resta intero all'inizio della sillaba.
                            syllables.append(current)
                            current = ""
                        } else {
                            // Consonanti separabili: la prima chiude la sillaba.
                            current.append(next)
                            syllables.append(current)
                            current = ""
                            i += 1
                        }
                    }
                }
            }

            i += 1
        }

        if !current.isEmpty { syllables.append(current) }

        // Una sillaba finale di sola consonante si riattacca alla precedente.
        if syllables.count > 1, let last = syllables.last, !last.contains(where: isVowel) {
            syllables.removeLast()
            syllables[syllables.count - 1] += last
        }

        return syllables.isEmpty ? [word] : syllables
    }
}
