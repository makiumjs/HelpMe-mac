import Foundation

/// Controlla il testo di partenza prima che raggiunga il cloud.
///
/// `StudentPseudonymizer` presidia la scheda dell'alunno, ma il riquadro dove
/// il docente incolla finisce nella richiesta com'è, e altrettanto fanno i
/// frammenti indicizzati. Nell'uso previsto lì va la verifica di matematica,
/// ma niente impedisce di incollarci un PEI.
///
/// Qui si avvisa e non si filtra: scartare una frase dal testo di partenza
/// mutilerebbe la verifica da trasformare e produrrebbe materiale sbagliato in
/// silenzio, peggio del problema che risolve. Solo il docente sa se quel nome
/// è il suo alunno o un personaggio del problema di fisica.
nonisolated public struct SourceTextScreening: Equatable, Sendable {
    public let reasons: [String]

    public var hasFindings: Bool { !reasons.isEmpty }

    public var warning: String? {
        guard hasFindings else { return nil }
        return "Prima di generare, controlla il testo di partenza: "
             + reasons.joined(separator: "; ")
             + ". Il testo di partenza viene inviato al servizio di IA così com'è, "
             + "a differenza della scheda dell'alunno che viene pseudonimizzata."
    }

    public static func of(
        sourceText: String,
        student: StudentProfile?,
        indexedExcerpts: [String] = []
    ) -> SourceTextScreening {
        var reasons: [String] = []

        if !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let student, StudentPseudonymizer.containsStudentName(sourceText, name: student.name) {
                reasons.append("contiene il nome dell'alunno")
            }
            let clinical = StudentPseudonymizer.clinicalTerms(in: sourceText)
            if !clinical.isEmpty { reasons.append(describe("contiene", clinical)) }
        }

        let excerpts = indexedExcerpts.joined(separator: "\n")
        if !excerpts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let clinical = StudentPseudonymizer.clinicalTerms(in: excerpts)
            if !clinical.isEmpty {
                reasons.append(describe("il documento indicizzato che verrà allegato contiene", clinical))
            }
            if let student, StudentPseudonymizer.containsStudentName(excerpts, name: student.name) {
                reasons.append("il documento indicizzato che verrà allegato contiene il nome dell'alunno")
            }
        }

        return SourceTextScreening(reasons: reasons)
    }

    /// Il messaggio che ferma la generazione, o nil se si può procedere.
    ///
    /// Sta qui e non dentro la vista: il controllo dev'essere sulla strada
    /// della generazione, non solo accanto al pulsante.
    public static func blockingMessage(
        screening: SourceTextScreening,
        reviewed: Bool,
        goesToCloud: Bool
    ) -> String? {
        guard goesToCloud, screening.hasFindings, !reviewed else { return nil }
        return (screening.warning ?? "") + " Se è materiale didattico, conferma e procedi."
    }

    private static func describe(_ prefix: String, _ terms: [String]) -> String {
        let shown = terms.prefix(4).map { "«\($0)»" }.joined(separator: ", ")
        let rest = terms.count > 4 ? " e altri \(terms.count - 4)" : ""
        return "\(prefix) riferimenti clinici o normativi: \(shown)\(rest)"
    }
}
