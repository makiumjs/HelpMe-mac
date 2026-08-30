import XCTest
import SwiftData
@testable import Helpme

/// L'app non semplifica il lessico — quello richiede di sapere quali parole
/// quell'alunno ha già. Rende il testo leggibile e misura dov'è difficile.
final class ReadabilityTests: XCTestCase {

    private let difficile = """
    La litosfera, che costituisce lo strato rigido più esterno del pianeta e che
    viene suddivisa in placche di dimensioni assai variabili, è caratterizzata da
    un comportamento fragile mentre l'astenosfera sottostante, poiché si trova a
    temperature notevolmente superiori, manifesta invece un comportamento plastico.
    """

    private let facile = """
    La litosfera è lo strato duro esterno della Terra.
    È divisa in placche. Le placche si muovono lentamente.
    """

    // MARK: - L'indice

    /// Gulpease è la formula tarata sull'italiano, non una traduzione del
    /// Flesch inglese: un testo facile deve stare molto sopra a uno difficile.
    func testTheEasyTextScoresHigherThanTheHardOne() {
        let duro = ReadabilityAnalyzer.analyze(difficile).gulpease
        let semplice = ReadabilityAnalyzer.analyze(facile).gulpease

        XCTAssertGreaterThan(semplice, duro, "facile=\(semplice) difficile=\(duro)")
        XCTAssertGreaterThan(semplice, 60, "Un testo di frasi brevi deve risultare leggibile.")
    }

    func testTheIndexStaysWithinItsRange() {
        for testo in [difficile, facile, "Ciao.", ""] {
            let valore = ReadabilityAnalyzer.analyze(testo).gulpease
            XCTAssertTrue((0...100).contains(valore), "\(valore) per «\(testo.prefix(20))»")
        }
    }

    func testTheVerdictSpeaksToWhoReadsNotToWhoMeasures() {
        XCTAssertTrue(ReadabilityAnalyzer.analyze(facile).verdict.contains("leggibile"))
        XCTAssertFalse(ReadabilityAnalyzer.analyze(difficile).verdict.isEmpty)
    }

    // MARK: - Perché una frase è difficile

    func testALongSentenceIsFlaggedWithItsLength() {
        let frase = ReadabilityAnalyzer.analyze(difficile).sentencesNeedingWork.first

        let motivi = try! XCTUnwrap(frase).reasons.joined(separator: " ")
        XCTAssertTrue(motivi.contains("parole"), motivi)
        XCTAssertTrue(motivi.contains("subordinate"), "Il periodo è annidato: \(motivi)")
    }

    /// Il passivo allontana chi agisce dall'azione, e chi legge con fatica
    /// perde proprio quello: chi fa che cosa.
    func testThePassiveVoiceIsRecognised() {
        XCTAssertTrue(ReadabilityAnalyzer.hasPassive("La legge viene applicata dal giudice."))
        XCTAssertTrue(ReadabilityAnalyzer.hasPassive("Il ponte è stato costruito nel 1890."))
        XCTAssertFalse(ReadabilityAnalyzer.hasPassive("Il giudice applica la legge."))
    }

    /// "L'astenosfera" e' la parola "astenosfera": senza togliere l'articolo
    /// elisa restava attaccata, non risultava rara, e il glossario
    /// dell'alunno non la ritrovava.
    func testRareWordsAreListedAmongTheReasons() {
        let lettura = ReadabilityAnalyzer.reading(of: "L'astenosfera manifesta un comportamento plastico.")
        XCTAssertTrue(lettura.rareWords.contains("astenosfera"), "\(lettura.rareWords)")
    }

    func testTheElidedArticleIsStrippedButStillCountsAsOneWord() {
        XCTAssertEqual(ReadabilityAnalyzer.withoutElision("l'astenosfera"), "astenosfera")
        XCTAssertEqual(ReadabilityAnalyzer.withoutElision("dell'acqua"), "acqua")
        XCTAssertEqual(ReadabilityAnalyzer.withoutElision("placche"), "placche")
        // Gulpease conta le parole come le separa uno spazio.
        XCTAssertEqual(ReadabilityAnalyzer.wordsOf("L'astenosfera è plastica.").count, 3)
    }

    func testAShortPlainSentenceIsNotFlagged() {
        let lettura = ReadabilityAnalyzer.reading(of: "Le placche si muovono lentamente.")
        XCTAssertFalse(lettura.needsWork, "\(lettura.reasons)")
    }

    // MARK: - La riformattazione, che non tocca le parole

    func testEverySentenceGoesOnItsOwnLine() {
        let formattato = HighReadabilityFormatter.format(facile)
        XCTAssertTrue(formattato.contains("È divisa in placche.\n\nLe placche si muovono lentamente."), formattato)
    }

    /// Non deve cambiare una parola: solo come il testo si presenta.
    func testNoWordIsChanged() {
        let originali = Set(ReadabilityAnalyzer.wordsOf(difficile).map { $0.lowercased() })
        let dopo = Set(ReadabilityAnalyzer.wordsOf(HighReadabilityFormatter.format(difficile)).map { $0.lowercased() })
        XCTAssertEqual(originali, dopo, "La riformattazione non semplifica: sposta soltanto.")
    }

    /// Un'enumerazione annunciata dai due punti si legge meglio come elenco.
    func testAnAnnouncedEnumerationBecomesAList() {
        let elenco = HighReadabilityFormatter.asList("I margini sono tre: divergenti, convergenti e trasformi.")
        XCTAssertNotNil(elenco)
        XCTAssertTrue(try! XCTUnwrap(elenco).contains("- divergenti"), elenco ?? "")
        XCTAssertTrue(try! XCTUnwrap(elenco).contains("- trasformi"), elenco ?? "")
    }

    /// Ma un inciso fra virgole non è un elenco: spezzarlo romperebbe la frase.
    func testACommaThatIsNotAnEnumerationIsLeftAlone() {
        XCTAssertNil(HighReadabilityFormatter.asList("La litosfera, che è rigida, si spezza."))
        XCTAssertNil(HighReadabilityFormatter.asList("Le placche si muovono lentamente."))
    }

    // MARK: - Il documento dice cosa non ha fatto

    func testTheDocumentAdmitsItDidNotSimplifyTheWords() {
        let documento = ClearTextComposer.compose(difficile)

        XCTAssertTrue(documento.contains("Gulpease"))
        XCTAssertTrue(documento.contains("vanno riscritte a mano"),
                      "Non deve spacciare una riformattazione per una semplificazione.")
    }

    // MARK: - Il glossario dell'alunno si riusa

    func testWordsAlreadyExplainedForThisStudentComeBack() {
        let documento = ClearTextComposer.compose(
            difficile,
            glossary: ["astenosfera": "lo strato morbido sotto la crosta"])

        XCTAssertTrue(documento.contains("Parole che hai già spiegato"), documento)
        XCTAssertTrue(documento.contains("lo strato morbido sotto la crosta"), documento)
    }

    func testAGlossaryWithEmptyBoxesOffersNothing() {
        let compilato = GlossaryComposer.compose(
            terms: [GlossaryTerm(term: "litosfera", context: "La litosfera è rigida.", occurrences: 1)],
            interest: "")

        XCTAssertTrue(GlossaryReader.definitions(from: compilato).isEmpty,
                      "Le caselle non compilate non sono definizioni.")
    }

    func testAFilledGlossaryIsReadBack() {
        let compilato = """
        ### Litosfera

        > La litosfera è lo strato rigido.

        **Che cosa vuol dire:** lo strato duro esterno della Terra

        **È come quando…** _____
        """
        XCTAssertEqual(GlossaryReader.definitions(from: compilato)["litosfera"],
                       "lo strato duro esterno della Terra")
    }

    // MARK: - Nell'app

    @MainActor
    func testTheFormatWorksWithNoEngineAndReusesTheStudentsGlossary() async throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff
        let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        alunno.personalGlossary = """
        ### Astenosfera

        **Che cosa vuol dire:** lo strato morbido sotto la crosta
        """
        vm.addStudent(alunno)
        vm.selectedFormat = .clearExplanation
        vm.sourceText = difficile

        XCTAssertTrue(vm.canGenerate)
        await vm.generateMaterial()

        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.generatedContent.contains("lo strato morbido sotto la crosta"),
                      "Il glossario dell'alunno deve tornare utile qui.")
        XCTAssertTrue(vm.statusMessage?.contains("Gulpease") ?? false, vm.statusMessage ?? "")
    }

    /// Il glossario compilato si conserva a parte, per servire più tardi.
    @MainActor
    func testAFilledGlossaryIsKeptForLater() throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        vm.addStudent(alunno)
        vm.selectedFormat = .glossary
        vm.generatedContent = """
        ### Litosfera

        **Che cosa vuol dire:** lo strato duro esterno
        """
        vm.rememberWork()

        XCTAssertFalse(alunno.personalGlossary.isEmpty)

        // Un altro materiale non deve cancellarlo.
        vm.selectedFormat = .deskCheatSheet
        vm.generatedContent = "## Formulario"
        vm.rememberWork()

        XCTAssertTrue(alunno.personalGlossary.contains("lo strato duro esterno"))
    }
}
