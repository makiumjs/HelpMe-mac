import XCTest
import SwiftData
@testable import Helpme

/// La parte noiosa del glossario è scovare i termini e ripescare la frase in
/// cui compaiono. Quella che vale — dirlo in parole che quell'alunno capisce
/// — richiede di conoscerlo, e resta al docente.
final class GlossaryExtractorTests: XCTestCase {

    private let brano = """
    La litosfera è lo strato rigido più esterno della Terra ed è suddivisa in
    placche che si muovono lentamente sopra l'astenosfera, uno strato plastico
    del mantello. Il movimento delle placche prende il nome di tettonica.
    Dove due placche si allontanano si forma una dorsale oceanica: il magma
    risale, solidifica e genera nuova crosta oceanica. Dove invece una placca
    sprofonda sotto un'altra si ha la subduzione, che produce vulcanismo.
    """

    private func terms() -> [String] { GlossaryExtractor.extract(from: brano).map(\.term) }

    func testTheTechnicalTermsAreFound() {
        let trovati = terms()
        for atteso in ["litosfera", "astenosfera", "subduzione", "tettonica", "vulcanismo"] {
            XCTAssertTrue(trovati.contains(atteso), "manca «\(atteso)»: \(trovati)")
        }
    }

    /// "Senza" era finito fra i termini da spiegare: l'analizzatore
    /// grammaticale a volte etichetta come sostantivo quello che non lo è.
    func testFunctionWordsAreNotTerms() {
        for parola in ["senza", "sopra", "invece", "questo", "quando"] {
            XCTAssertFalse(terms().contains(parola), "«\(parola)» non è un termine di glossario")
        }
    }

    /// "Il magma risale" produceva la voce "ridere": lemma di un verbo
    /// coniugato scambiato per sostantivo.
    func testAConjugatedVerbDoesNotBecomeATerm() {
        XCTAssertFalse(terms().contains("ridere"), "\(terms())")
        XCTAssertTrue(GlossaryExtractor.isInfinitive("ridere"))
        XCTAssertFalse(GlossaryExtractor.isInfinitive("risale"))
    }

    /// Ma un sostantivo che finisce come un infinito resta: "cratere" e
    /// "potere" non sono verbi coniugati.
    func testANounThatLooksLikeAnInfinitiveSurvives() {
        let trovati = GlossaryExtractor.extract(from:
            "Il cratere del vulcano si è formato sopra il condotto principale. "
            + "Il cratere raccoglie i materiali eruttati durante l'esplosione."
        ).map(\.term)
        XCTAssertTrue(trovati.contains("cratere"), "\(trovati)")
    }

    /// "Placca" e "placche" sono una voce sola di glossario, non due.
    func testSingularAndPluralAreOneEntry() {
        let placche = GlossaryExtractor.extract(from: brano).filter { $0.term.hasPrefix("plac") }

        XCTAssertEqual(placche.count, 1, "\(placche.map(\.term))")
        XCTAssertGreaterThan(placche[0].occurrences, 2, "Le occorrenze delle due forme si sommano.")
    }

    /// La frase di contesto evita al docente di tornare al libro.
    func testEachTermCarriesTheSentenceWhereItAppears() {
        let litosfera = try! XCTUnwrap(GlossaryExtractor.extract(from: brano).first { $0.term == "litosfera" })

        XCTAssertTrue(litosfera.context.localizedCaseInsensitiveContains("litosfera"))
        XCTAssertGreaterThan(litosfera.context.count, 20)
    }

    /// Una parola che il vocabolario italiano di sistema non conosce è quasi
    /// sempre un tecnicismo. Il contrario non vale, ed è per questo che è una
    /// spinta e non un criterio.
    func testTheRarityBoostFavoursTechnicalWords() {
        XCTAssertGreaterThan(
            GlossaryExtractor.score("litosfera", occurrences: 1),
            GlossaryExtractor.score("processo", occurrences: 1)
        )
    }

    // MARK: - Il documento

    func testTheSheetLeavesTheDefinitionToTheTeacher() {
        let scheda = GlossaryComposer.compose(
            terms: [GlossaryTerm(term: "litosfera", context: "La litosfera è lo strato rigido.", occurrences: 2)],
            interest: "Informatica e Gaming")

        XCTAssertTrue(scheda.contains("### Litosfera"))
        XCTAssertTrue(scheda.contains("> La litosfera è lo strato rigido."))
        XCTAssertTrue(scheda.contains("Che cosa vuol dire:"))
        XCTAssertTrue(scheda.contains("Informatica e Gaming"), "L'analogia parte dagli interessi dell'alunno.")
    }

    func testATextWithoutTechnicalTermsSaysSoInsteadOfInventing() {
        let scheda = GlossaryComposer.compose(terms: [], interest: "")
        XCTAssertTrue(scheda.contains("Non ho riconosciuto termini tecnici"), scheda)
    }

    // MARK: - Nell'app

    @MainActor
    func testTheGlossaryIsBuiltWithNoEngine() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.selectedFormat = .glossary
        vm.sourceText = brano

        XCTAssertTrue(vm.canGenerate)
        await vm.generateMaterial()

        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.generatedContent.contains("Litosfera"), vm.generatedContent)
    }

    /// Ma se il docente sceglie un motore a mano, vuole le definizioni
    /// scritte: non gli si impone la scheda da compilare.
    @MainActor
    func testChoosingAnEngineByHandGoesBackToTheModel() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff      // nessun motore utilizzabile
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.selectedFormat = .glossary
        vm.engineOverride = .gemini                       // scelto a mano, ma senza chiave
        vm.sourceText = brano

        await vm.generateMaterial()

        XCTAssertTrue(vm.generatedContent.isEmpty)
        XCTAssertNotNil(vm.errorMessage, "Deve dire che quel motore non è disponibile, non ripiegare in silenzio.")
    }
}
