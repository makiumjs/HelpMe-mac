import Foundation
nonisolated enum ItalianSyllabifier {

    private static let vowels = Set("aeiouàèéìòóùAEIOUÀÈÉÌÒÓÙ")
    private static let inseparableClusters: Set<String> = [
        "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl", "pr",
        "tr", "vr", "sb", "sc", "sd", "sf", "sg", "sl", "sm", "sn", "sp",
        "sq", "sr", "st", "sv", "gn", "ch", "gh", "qu", "sch"
    ]

    private static let digraphs: Set<String> = ["ch", "gh", "gn", "gl", "sc", "qu"]

    private static func isVowel(_ character: Character) -> Bool {
        vowels.contains(character)
    }
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

            let computed = compute(text)

            lock.lock()
            input = text
            output = computed
            lock.unlock()

            return computed
        }
    }

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
                  
                    i += 1
                    continue
                }

                let following = i + 2 < characters.count ? characters[i + 2] : nil

                if let following {
                    if isVowel(following) {
                   
                        syllables.append(current)
                        current = ""
                    } else {
                        let cluster = String([next, following]).lowercased()
                        let isDoubleConsonant = next.lowercased() == following.lowercased()

                        if isDoubleConsonant {                                                    current.append(next)
                            syllables.append(current)
                            current = ""
                            i += 1
                        } else if inseparableClusters.contains(cluster) || digraphs.contains(cluster) {
                          
                            syllables.append(current)
                            current = ""
                        } else {
                          
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

        if syllables.count > 1, let last = syllables.last, !last.contains(where: isVowel) {
            syllables.removeLast()
            syllables[syllables.count - 1] += last
        }

        return syllables.isEmpty ? [word] : syllables
    }
}
