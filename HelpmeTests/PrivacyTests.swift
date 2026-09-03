import XCTest
import SwiftData
@testable import Helpme

/// I documenti prodotti finiscono nel fascicolo dell'alunno e sotto gli occhi
/// di tutto il Consiglio di Classe: i riferimenti diagnostici non devono
/// entrarci. Questi test presidiano quel confine.
///
/// Che i dati non escano dal Mac non e' piu' compito di un filtro: lo
/// impedisce la sandbox, e lo presidia `OfflineGuaranteeTests`.
@MainActor
final class PrivacyTests: XCTestCase {

    private func makeStudent() -> StudentProfile {
        StudentProfile(
            name: "Marco Rossi",
            classInfo: "3ª A Agrario",
            programType: .minimi,
            interest: "Meccanica Agraria e Trattori",
            notes: "DSA (dislessia e discalculia) certificata. Ottima comprensione per immagini e schemi pratici. Lavora bene in coppia."
        )
    }

    // MARK: - Riferimenti normativi spezzati dalla punteggiatura

    /// Il difetto originale: le note venivano divise su OGNI punto prima di
    /// cercare i termini clinici, e "L. 104" — che un punto ce l'ha dentro —
    /// finiva spezzato in "L" + "104", così nessuno dei due pezzi somigliava
    /// più a un termine della lista. Il riferimento alla certificazione di
    /// disabilità di un minore partiva verso il cloud in chiaro.
    func testLegge104ReferenceIsFilteredDespiteInternalPeriod() {
        for note in [
            "Alunno certificato ai sensi della L. 104.",
            "Rientra nella L.104 del 1992.",
            "Segue percorso ex legge 104.",
            "Certificazione L. 104/1992 agli atti."
        ] {
            let filtered = StudentPseudonymizer.filterClinicalReferences(from: note)
            XCTAssertFalse(
                StudentPseudonymizer.containsClinicalTerm(filtered),
                "riferimento normativo trapelato da «\(note)» → «\(filtered)»"
            )
        }
    }

    /// Stesso difetto sull'altro fronte: "qi " era scritto con lo spazio
    /// finale per non scattare dentro altre parole, ma una frase che finisce
    /// con "il QI." perdeva proprio quello spazio nello split.
    func testIqReferenceIsFilteredAtEndOfSentence() {
        let filtered = StudentPseudonymizer.filterClinicalReferences(
            from: "Buono in matematica. È stato somministrato il QI."
        )
        XCTAssertFalse(filtered.lowercased().contains("qi"),
                       "il riferimento psicometrico è trapelato: «\(filtered)»")
    }

    /// Il confine di parola deve restare: "qi" e "icf" non devono scattare
    /// dentro parole comuni, altrimenti il filtro mangia le osservazioni.
    func testShortTermsDoNotMatchInsideOtherWords() {
        let note = "Qui lavora con calma. Il clima pacifico della classe aiuta."
        let filtered = StudentPseudonymizer.filterClinicalReferences(from: note)
        XCTAssertTrue(filtered.contains("Qui lavora con calma"), "falso positivo su «qui»")
        XCTAssertTrue(filtered.contains("pacifico"), "falso positivo su «pacifico»")
    }

    /// Le abbreviazioni con il punto non devono spezzare la frase a metà,
    /// altrimenti un frammento senza contesto sfugge al filtro.
    func testSentenceSplittingKeepsAbbreviationsIntact() {
        let sentences = StudentPseudonymizer.splitIntoSentences(
            "Rientra nella L. 104 del 1992. Lavora bene in gruppo."
        )
        XCTAssertEqual(sentences.count, 2, "atteso split solo sul confine vero: \(sentences)")
        XCTAssertTrue(sentences[0].contains("L. 104"), "l'abbreviazione è stata spezzata: \(sentences)")
    }

    /// La rete di sicurezza: se dopo il filtro per frasi resta comunque un
    /// termine clinico, si scarta tutto invece di lasciarlo passare.
    func testSafetyNetDropsEverythingIfATermSurvives() {
        let filtered = StudentPseudonymizer.filterClinicalReferences(from: "Diagnosi ADHD")
        XCTAssertEqual(filtered, "", "un termine sopravvissuto deve svuotare la nota")
    }

    func testDidacticNotesStillSurviveTheStricterFilter() {
        let filtered = StudentPseudonymizer.filterClinicalReferences(
            from: "Ottima comprensione per immagini e schemi pratici. Lavora bene in coppia."
        )
        XCTAssertTrue(filtered.contains("Ottima comprensione per immagini e schemi pratici"))
        XCTAssertTrue(filtered.contains("Lavora bene in coppia"))
    }
}
