import Foundation

public nonisolated enum DeskCardEntryKind: String, Sendable {
    case formula
    case definition
    case datum
}

public nonisolated struct DeskCardEntry: Equatable, Sendable {
    public let kind: DeskCardEntryKind
    public let text: String
}

/// Trova formule, definizioni e dati dentro il testo della lezione.
///
/// Il formulario è uno strumento compensativo (L. 170/2010): sta sul banco
/// durante la lezione e la verifica, e il suo valore è essere **corto**. Per
/// questo l'app propone e il docente taglia: il materiale esce nell'editor,
/// dove si toglie quello che non serve.
///
/// Non "capisce" la lezione: riconosce forme. Una riga con un uguale e delle
/// lettere è una formula; "X è Y" e "prende il nome di X" sono definizioni;
/// un numero con un'unità di misura è un dato. Sono le tre cose che uno
/// studente cerca sul banco quando si blocca.
public nonisolated enum DeskCardExtractor {

    public static func extract(from text: String, limit: Int = 18) -> [DeskCardEntry] {
        var entries: [DeskCardEntry] = []
        var seen = Set<String>()

        for sentence in GlossaryExtractor.splitIntoSentences(text) {
            let clean = sentence
                .trimmingCharacters(in: CharacterSet(charactersIn: "-*• \t"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.count <= 220 else { continue }

            guard let kind = classify(clean) else { continue }
            let key = clean.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            entries.append(DeskCardEntry(kind: kind, text: clean))
        }

        // Prima le formule: sono la cosa che si dimentica per prima e che
        // serve piu' in fretta durante una prova.
        let order: [DeskCardEntryKind] = [.formula, .definition, .datum]
        return order.flatMap { kind in entries.filter { $0.kind == kind } }
            .prefix(limit)
            .map { $0 }
    }

    static func classify(_ sentence: String) -> DeskCardEntryKind? {
        if isFormula(sentence) { return .formula }
        if isDefinition(sentence) { return .definition }
        if isDatum(sentence) { return .datum }
        return nil
    }

    /// Un uguale fra due espressioni, con almeno una lettera per parte.
    static func isFormula(_ sentence: String) -> Bool {
        guard let equals = sentence.firstIndex(of: "=") else { return false }
        let left = sentence[sentence.startIndex..<equals]
        let right = sentence[sentence.index(after: equals)...]

        guard left.contains(where: \.isLetter), !right.isEmpty else { return false }
        // Il lato sinistro di una formula e' corto: "F", "P", "Consumo".
        // "La velocita' della luce nel vuoto e' pari a c = 3·10^8 m/s" ha un
        // lato sinistro lungo, ed e' comunque una formula: si guarda l'ultima
        // parola prima dell'uguale.
        let head = left.split(whereSeparator: { $0 == " " }).last ?? ""
        return head.count <= 24 && right.contains(where: { $0.isLetter || $0.isNumber })
    }

    private static let definitionMarkers = [
        " si chiama ", " prende il nome di ", " si definisce ", " si dice ",
        " è detto ", " è detta ", " consiste in ", " è l'insieme ", " indica "
    ]

    static func isDefinition(_ sentence: String) -> Bool {
        let lower = sentence.lowercased()
        if definitionMarkers.contains(where: { lower.contains($0) }) { return true }

        // "La litosfera è lo strato rigido…": soggetto breve, verbo essere,
        // e un predicato che spiega. Il soggetto lungo di solito racconta un
        // fatto, non definisce.
        guard let range = lower.range(of: " è ") else { return false }
        let subject = lower[lower.startIndex..<range.lowerBound]
        let predicate = lower[range.upperBound...]
        return subject.split(separator: " ").count <= 4 && predicate.count >= 12
    }

    /// Un numero seguito da un'unita' di misura.
    static func isDatum(_ sentence: String) -> Bool {
        let pattern = #"\d+([.,]\d+)?\s*(k?[gmlNJWVA]|km|cm|mm|kg|kW|kWh|MPa|Pa|°C|m/s|km/h|g/kWh|kg/l)\b"#
        return sentence.range(of: pattern, options: [.regularExpression]) != nil
    }
}

/// Impagina il formulario da banco.
public nonisolated enum DeskCardComposer {

    public static func compose(entries: [DeskCardEntry], subject: String = "") -> String {
        guard !entries.isEmpty else {
            return "Non ho riconosciuto formule, definizioni o dati in questo testo. "
                 + "Il formulario si costruisce da una spiegazione o da un capitolo, "
                 + "non da un elenco di consegne."
        }

        var parts: [String] = ["## Formulario e scheda da banco"]
        if !subject.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append("**\(subject)**")
        }

        for (kind, title) in [(DeskCardEntryKind.formula, "Formule"),
                              (.definition, "Definizioni da ricordare"),
                              (.datum, "Dati e unità di misura")] {
            let group = entries.filter { $0.kind == kind }
            guard !group.isEmpty else { continue }
            parts.append("### \(title)\n\n" + group.map { "- \($0.text)" }.joined(separator: "\n"))
        }

        parts.append("""
        ---

        *Strumento compensativo (L. 170/2010): resta sul banco durante la lezione \
        e la verifica. Vale se è corto — togli quello che l'alunno ha già acquisito.*
        """)
        return parts.joined(separator: "\n\n")
    }
}
