import Foundation
nonisolated public enum SourceTextCheck {
    private static let imperatives = [
        "genera", "generami", "crea", "creami", "fai", "fammi", "scrivi",
        "scrivimi", "prepara", "preparami", "trasforma", "adatta", "elabora",
        "produci", "dammi", "mostrami", "riassumi", "sintetizza", "estrai",
        "converti", "traduci", "semplifica", "usa", "utilizza", "prendi"
    ]
    private static let instructionLengthLimit = 200

    public static func looksLikeAnInstruction(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count < instructionLengthLimit else { return false }

        let firstWord = trimmed
            .lowercased()
            .prefix { $0.isLetter }
        guard !firstWord.isEmpty else { return false }

        return imperatives.contains(String(firstWord))
    }
    public static func instructionExplanation(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = trimmed.count > 60 ? String(trimmed.prefix(60)) + "…" : trimmed
        return "«\(quoted)» sembra una richiesta all'IA, non una lezione. "
             + "In questo riquadro va il testo curricolare da adattare: incollalo, "
             + "oppure premi «Importa» e il documento ci finisce da solo."
    }
}
