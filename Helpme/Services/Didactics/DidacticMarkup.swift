import Foundation

/// La sintassi concordata tra il prompt e l'app.
///
/// `DidacticFormat` chiede al modello di marcare la risposta esatta con
/// `[x]` e di separare concetto e dettaglio con ` :: `. Quella conoscenza
/// era ripetuta a mano in quattro file — i due parser, il presentatore per
/// lo studente e l'esportazione — e aveva già cominciato a divergere: chi
/// accettava la lineetta come separatore e chi no, chi riconosceva `[]`
/// vuoto e chi no.
///
/// Sta tutta qui, così cambiare il formato richiesto nel prompt significa
/// cambiare un posto solo, e nessun consumatore può restare indietro in
/// silenzio — cosa che, sul presentatore, vorrebbe dire mostrare allo
/// studente la risposta giusta.
nonisolated enum DidacticMarkup {

    /// I segni di elenco che il modello usa, in ordine di frequenza.
    static let bulletPrefixes = ["- ", "* ", "+ "]

    /// Separatori tra concetto e dettaglio, o tra opzione e spiegazione.
    static let detailSeparators = [" :: ", "::", " — ", " – ", " | "]

    /// Un'opzione di quiz riconosciuta in una riga di testo.
    struct QuizOption {
        /// Il segno di elenco originale (`"- "`), per ricostruire la riga.
        var bullet: String
        /// Il testo dell'opzione, senza marcatore né spiegazione.
        var text: String
        var isCorrect: Bool
        /// La spiegazione formativa, se presente dopo il separatore.
        var explanation: String?
    }

    /// Riconosce `- [x] Testo :: spiegazione` e le sue varianti.
    ///
    /// Restituisce `nil` se la riga non è un'opzione di quiz — cioè per
    /// qualunque punto elenco normale, che resta un punto elenco.
    static func quizOption(in line: String) -> QuizOption? {
        for bullet in bulletPrefixes {
            guard line.hasPrefix(bullet) else { continue }

            let rest = String(line.dropFirst(bullet.count))
            let lowered = rest.lowercased()

            let marker: String
            let isCorrect: Bool
            if lowered.hasPrefix("[x]")      { marker = "[x]"; isCorrect = true }
            else if lowered.hasPrefix("[ ]") { marker = "[ ]"; isCorrect = false }
            else if lowered.hasPrefix("[]")  { marker = "[]";  isCorrect = false }
            else { return nil }

            let body = String(rest.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            let (text, explanation) = splitDetail(body)
            guard !text.isEmpty else { return nil }

            return QuizOption(bullet: bullet, text: text, isCorrect: isCorrect, explanation: explanation)
        }
        return nil
    }

    /// Vero se la riga è un'opzione di quiz: serve a chi deve solo
    /// escluderla, come il parser della mappa concettuale.
    static func isQuizOption(_ line: String) -> Bool {
        quizOption(in: line) != nil
    }

    /// Divide `"Concetto :: dettaglio"` sul primo separatore utile.
    ///
    /// Entrambe le metà devono essere non vuote, altrimenti il separatore
    /// era parte del testo e la riga resta intera.
    static func splitDetail(_ text: String) -> (head: String, detail: String?) {
        for separator in detailSeparators {
            guard let range = text.range(of: separator) else { continue }
            let head = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let detail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !head.isEmpty && !detail.isEmpty { return (head, detail) }
        }
        return (text, nil)
    }
}
