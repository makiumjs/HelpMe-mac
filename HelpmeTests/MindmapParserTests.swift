import XCTest
@testable import Helpme

/// AC5, parte mappa: l'elenco puntato dell'IA diventa un albero navigabile.
final class MindmapParserTests: XCTestCase {

    func testNestedBulletsBecomeAHierarchy() {
        let nodes = MindmapParser.parse("""
        - Il motore a quattro tempi
          - Aspirazione
            - Il pistone scende
          - Compressione
            - Il pistone risale
        """)

        XCTAssertEqual(nodes.count, 1)
        let root = try! XCTUnwrap(nodes.first)
        XCTAssertEqual(root.title, "Il motore a quattro tempi")
        XCTAssertEqual(root.children.map(\.title), ["Aspirazione", "Compressione"])
        XCTAssertEqual(root.children.first?.children.map(\.title), ["Il pistone scende"])
        XCTAssertEqual(root.depth, 3)
        XCTAssertEqual(root.totalCount, 5)
    }

    /// Il modello alterna due e quattro spazi di rientro: la gerarchia deve
    /// venire fuori uguale, perché è la stessa mappa.
    func testFourSpaceIndentationGivesTheSameShapeAsTwo() {
        let twoSpaces = MindmapParser.parse("""
        - Radice
          - Ramo
            - Foglia
        """)
        let fourSpaces = MindmapParser.parse("""
        - Radice
            - Ramo
                - Foglia
        """)

        XCTAssertEqual(twoSpaces.first?.depth, fourSpaces.first?.depth)
        XCTAssertEqual(twoSpaces.first?.children.first?.children.first?.title, "Foglia")
        XCTAssertEqual(fourSpaces.first?.children.first?.children.first?.title, "Foglia")
    }

    func testTabsCountAsIndentation() {
        let nodes = MindmapParser.parse("- Radice\n\t- Ramo\n\t\t- Foglia")
        XCTAssertEqual(nodes.first?.children.first?.children.first?.title, "Foglia")
    }

    func testHeadingsActAsRootsForTheBulletsBelow() {
        let nodes = MindmapParser.parse("""
        # La fotosintesi
        - Fase luminosa
        - Fase oscura
        """)

        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.title, "La fotosintesi")
        XCTAssertEqual(nodes.first?.children.map(\.title), ["Fase luminosa", "Fase oscura"])
    }

    // MARK: - Titolo e dettaglio

    func testDoubleColonSeparatesTitleFromDetail() {
        let nodes = MindmapParser.parse("- Clorofilla :: il pigmento verde che cattura la luce")
        XCTAssertEqual(nodes.first?.title, "Clorofilla")
        XCTAssertEqual(nodes.first?.detail, "il pigmento verde che cattura la luce")
    }

    func testShortColonPrefixIsTreatedAsATitle() {
        let nodes = MindmapParser.parse("- Stomi: aperture della foglia")
        XCTAssertEqual(nodes.first?.title, "Stomi")
        XCTAssertEqual(nodes.first?.detail, "aperture della foglia")
    }

    /// In una frase normale i due punti non devono spezzare il testo:
    /// il titolo diventerebbe un pezzo di discorso senza senso.
    func testColonInsideALongSentenceDoesNotSplit() {
        let long = "Il processo avviene in due fasi distinte che si susseguono senza interruzione nel cloroplasto: ecco come"
        let nodes = MindmapParser.parse("- \(long)")
        XCTAssertNil(nodes.first?.detail)
        XCTAssertEqual(nodes.first?.title, long)
    }

    func testMarkdownEmphasisIsStrippedFromTitles() {
        let nodes = MindmapParser.parse("- **Clorofilla** :: pigmento *verde*")
        XCTAssertEqual(nodes.first?.title, "Clorofilla")
        XCTAssertEqual(nodes.first?.detail, "pigmento verde")
    }

    // MARK: - Robustezza

    func testPlainProseProducesNoNodes() {
        XCTAssertTrue(MindmapParser.parse("Questo è solo un paragrafo di testo continuo.").isEmpty)
        XCTAssertTrue(MindmapParser.parse("").isEmpty)
    }

    func testHorizontalRulesAreIgnored() {
        let nodes = MindmapParser.parse("- Radice\n---\n- Altra radice")
        XCTAssertEqual(nodes.map(\.title), ["Radice", "Altra radice"])
    }

    func testMultipleRootsArePreserved() {
        let nodes = MindmapParser.parse("""
        - Prima radice
          - figlio
        - Seconda radice
          - figlio
        """)
        XCTAssertEqual(nodes.map(\.title), ["Prima radice", "Seconda radice"])
        XCTAssertEqual(nodes.last?.children.count, 1)
    }

    /// Un salto di livello (da 1 a 3) non deve inventare nodi vuoti né
    /// perdere la voce: si attacca al genitore più profondo disponibile.
    func testSkippedIndentLevelDoesNotLoseNodes() {
        let nodes = MindmapParser.parse("""
        - Radice
            - Nipote saltando un livello
        - Altra radice
        """)
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes.first?.children.count, 1)
        XCTAssertEqual(nodes.first?.children.first?.title, "Nipote saltando un livello")
    }

    func testNumberedListsAreAcceptedAsBullets() {
        let nodes = MindmapParser.parse("""
        1. Primo passo
        2. Secondo passo
        """)
        XCTAssertEqual(nodes.map(\.title), ["Primo passo", "Secondo passo"])
    }

    func testDifferentBulletMarkersAreEquivalent() {
        for marker in ["-", "*", "+", "•"] {
            let nodes = MindmapParser.parse("\(marker) Concetto")
            XCTAssertEqual(nodes.first?.title, "Concetto", "Il segno «\(marker)» non è stato riconosciuto")
        }
    }

    /// Il formato che il prompt chiede al modello deve essere quello che il
    /// parser legge meglio: se i due divergono, la mappa resta testo.
    func testTheFormatRequestedInThePromptParsesCorrectly() {
        let asRequested = """
        - Tema principale
          - Concetto chiave :: spiegazione breve del concetto
            - Dettaglio o esempio pratico
          - Secondo concetto chiave
        """
        let nodes = MindmapParser.parse(asRequested)

        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.children.count, 2)
        XCTAssertEqual(nodes.first?.children.first?.detail, "spiegazione breve del concetto")
        XCTAssertEqual(nodes.first?.depth, 3)
    }

    /// Un materiale in formato quiz non è una mappa: le righe con la
    /// casella di spunta sono opzioni di risposta, e prese per concetti
    /// darebbero nodi intitolati "[ ] Aspirazione".
    func testQuizCheckboxLinesAreNotConcepts() {
        let quiz = """
        ### Domanda 1
        Durante quale fase il pistone comprime la miscela?
        - [ ] Aspirazione :: no, in aspirazione il pistone scende
        - [x] Compressione :: esatto, il pistone risale
        - [ ] Scoppio :: la candela accende la miscela
        """
        let nodes = MindmapParser.parse(quiz)
        let titles = nodes.flatMap { [$0.title] + $0.children.map(\.title) }
        XCTAssertFalse(titles.contains { $0.contains("[") },
                       "Le caselle di spunta non devono diventare nodi: \(titles)")
    }

    func testConceptMapPromptStillDescribesTheParsedFormat() {
        let prompt = DidacticFormat.conceptMap.systemPromptTemplate
        XCTAssertTrue(prompt.contains("::"), "Il prompt deve chiedere il separatore che il parser legge")
        XCTAssertTrue(prompt.contains("DUE spazi"), "Il prompt deve fissare il passo di rientro")
    }
}
