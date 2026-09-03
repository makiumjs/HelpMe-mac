import Foundation

/// Le citazioni normative dell'app, centralizzate e aggiornate alla legislazione vigente.
///
/// Quadro normativo di riferimento:
/// 1. D.I. 182/2020 coordinato con D.I. 153/2023 (Modelli nazionali PEI, 4 dimensioni, GLO e art. 15 prove equipollenti).
/// 2. D.Lgs. 3 maggio 2024, n. 62 (Riforma della disabilità: accomodamento ragionevole ex art. 3 e nuova terminologia ex art. 4).
/// 3. D.L. 71/2024 convertito in L. 106/2024 (Misure urgenti per il sostegno e continuità didattica).
/// 4. L. 170/2010 e D.M. 5669/2011 con Linee Guida allegate (Diritto allo studio per alunni con DSA).
/// 5. Linee Guida ISS 2022 (Consensus e raccomandazioni cliniche sui DSA).
/// 6. D.Lgs. 62/2017, art. 20 (Esami di Stato e prove equipollenti).
public enum LegalFramework: Sendable {
    /// Il decreto sul PEI, nel testo coordinato con la modifica del 2023.
    public static let interministerialDecree = "D.I. 182/2020 come modificato dal D.I. 153/2023"

    /// La forma breve, per un pulsante o una riga stretta.
    public static let interministerialDecreeShort = "D.I. 182/2020 e s.m.i."

    /// La nota da apporre dopo un articolo citato: "art. 10 — testo coordinato con il D.I. 153/2023".
    public static let coordinatedNote = "testo coordinato con il D.I. 153/2023"

    /// La legge quadro sui diritti delle persone con disabilità (L. 104/1992 e D.Lgs. 62/2024).
    public static let frameworkLaw = "L. 104/1992 e D.Lgs. 62/2024"

    /// Decreto legislativo 3 maggio 2024, n. 62 (accomodamento ragionevole e progetto di vita).
    public static let disabilityReformLaw = "D.Lgs. 62/2024"

    /// La legge sui DSA.
    public static let dsaLaw = "L. 170/2010"

    /// Il decreto attuativo con le Linee guida DSA scolastiche allegate (tuttora vigenti per il MIM).
    public static let dsaDecree = "D.M. 5669/2011"

    /// Linee guida cliniche Istituto Superiore di Sanità sui DSA (aggiornamento 2022).
    public static let dsaIssGuidelines = "Linee Guida ISS 2022"

    /// Decreto legislativo sulla valutazione ed esami di Stato (prove equipollenti).
    public static let evaluationDecree = "D.Lgs. 62/2017, art. 20"

    /// Decreto-Legge 71/2024 convertito in Legge 106/2024 (continuità didattica su sostegno).
    public static let continuityLaw = "D.L. 71/2024 (L. 106/2024)"

    /// Nota sull'accomodamento ragionevole per prove equipollenti e strumenti compensativi.
    public static let reasonableAccommodationNote = "Accomodamento ragionevole ai sensi dell'art. 3 D.Lgs. 62/2024"

    /// Tutte le fonti primarie insieme, per l'intestazione formale dei documenti esportati.
    public static let full = "\(interministerialDecree), \(frameworkLaw), \(dsaLaw), \(dsaDecree)"
}
