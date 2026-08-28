import XCTest
import SwiftData
@testable import Helpme

/// I dati che escono dal dispositivo verso Google Gemini riguardano minori
/// con disabilità: questi test presidiano il confine.
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

    func testPromptDoesNotContainStudentName() {
        let prompt = StudentPseudonymizer.promptProfile(for: makeStudent())
        XCTAssertFalse(prompt.contains("Marco"), "il nome non deve uscire dal dispositivo")
        XCTAssertFalse(prompt.contains("Rossi"))
        XCTAssertTrue(prompt.contains(StudentPseudonymizer.placeholder))
    }

    func testPromptDoesNotContainDiagnosis() {
        let prompt = StudentPseudonymizer.promptProfile(for: makeStudent()).lowercased()
        for term in ["dislessia", "discalculia", "dsa", "certificata"] {
            XCTAssertFalse(prompt.contains(term), "termine clinico trapelato: \(term)")
        }
    }

    func testPromptKeepsDidacticObservations() {
        let prompt = StudentPseudonymizer.promptProfile(for: makeStudent())
        XCTAssertTrue(prompt.contains("Ottima comprensione per immagini e schemi pratici"),
                      "le osservazioni didattiche servono e non identificano nessuno")
        XCTAssertTrue(prompt.contains("Lavora bene in coppia"))
        XCTAssertTrue(prompt.contains("Meccanica Agraria e Trattori"))
    }

    func testClassIsGeneralizedWithoutSection() {
        XCTAssertEqual(StudentPseudonymizer.generalizeClass("3ª A Agrario"), "3º anno, indirizzo Agrario")
        XCTAssertEqual(StudentPseudonymizer.generalizeClass("5ª B"), "5º anno di scuola secondaria di II grado")
        XCTAssertEqual(StudentPseudonymizer.generalizeClass(""), "scuola secondaria di II grado")
    }

    func testIdentityIsRestoredLocally() {
        let cloudAnswer = "La verifica è calibrata su \(StudentPseudonymizer.placeholder), che potrà usare il formulario."
        let restored = StudentPseudonymizer.restoreIdentity(in: cloudAnswer, name: "Marco Rossi")
        XCTAssertEqual(restored, "La verifica è calibrata su Marco Rossi, che potrà usare il formulario.")
        XCTAssertFalse(restored.contains(StudentPseudonymizer.placeholder))
    }

    /// Controllo di fondo sul prompt completo, non solo sul blocco profilo.
    func testFullPromptIsFreeOfIdentifiers() throws {
        let context = ModelContext(PersistenceController(inMemory: true).container)
        let viewModel = AppViewModel(modelContext: context)
        let student = makeStudent()
        viewModel.addStudent(student)
        viewModel.sourceText = "Descrivi il ciclo Otto a quattro tempi."

        let prompt = viewModel.buildPrompt(for: student)

        XCTAssertFalse(prompt.contains("Marco Rossi"))
        XCTAssertFalse(prompt.lowercased().contains("dislessia"))
        XCTAssertTrue(prompt.contains("ciclo Otto"), "il contenuto didattico deve esserci")
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

    func testApiKeyIsNotStoredInUserDefaults() {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        for (key, value) in defaults {
            guard let string = value as? String, string.count > 20 else { continue }
            XCTAssertFalse(key.lowercased().contains("gemini"),
                           "la API key non deve finire nei preferences: \(key)")
        }
    }
}
