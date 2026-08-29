import Foundation

/// Riconosce quando il testo di partenza non è una lezione ma una richiesta
/// scritta all'IA.
///
/// Successo reale, 29 agosto 2026: nel riquadro del testo curricolare è
/// finito «genera verifica sulla base del documento». L'app l'ha preso per
/// la lezione da trasformare, il recupero documentale ha riempito il vuoto
/// con i frammenti dell'unico documento indicizzato — un articolo tecnico —
/// e ne è uscita una verifica equipollente su come estrarre URL di LinkedIn,
/// con l'intestazione dell'istituto sopra.
///
/// Il rischio non è simmetrico. Bloccare per sbaglio una lezione vera costa
/// al docente un secondo tentativo; lasciar passare una richiesta produce un
/// documento ufficiale, dall'aria credibile, che finisce nel fascicolo di un
/// alunno con disabilità.
nonisolated public enum SourceTextCheck {

    /// Verbi con cui si comincia a dare un ordine, non a esporre una lezione.
    private static let imperatives = [
        "genera", "generami", "crea", "creami", "fai", "fammi", "scrivi",
        "scrivimi", "prepara", "preparami", "trasforma", "adatta", "elabora",
        "produci", "dammi", "mostrami", "riassumi", "sintetizza", "estrai",
        "converti", "traduci", "semplifica", "usa", "utilizza", "prendi"
    ]

    /// Oltre questa lunghezza è un testo, qualunque parola lo apra: una
    /// lezione può benissimo cominciare con "Prendi un cilindro di raggio r".
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

    /// Cosa dire al docente. Nomina il suo testo, così è chiaro di cosa si
    /// sta parlando, e indica le due strade per uscirne.
    public static func instructionExplanation(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = trimmed.count > 60 ? String(trimmed.prefix(60)) + "…" : trimmed
        return "«\(quoted)» sembra una richiesta all'IA, non una lezione. "
             + "In questo riquadro va il testo curricolare da adattare: incollalo, "
             + "oppure premi «Importa» e il documento ci finisce da solo."
    }
}
