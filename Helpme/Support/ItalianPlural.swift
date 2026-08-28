import Foundation

/// Concordanza di numero in italiano.
///
/// "1 documenti, 1 frammenti" è il genere di sciatteria che in un documento
/// scolastico si nota subito, e l'app la scriveva in più punti.
enum Plural {
    /// `Plural.it(1, "frammento", "frammenti")` → "1 frammento".
    static func it(_ count: Int, _ singular: String, _ plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}
