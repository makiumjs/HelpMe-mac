import XCTest
import SwiftData
@testable import Helpme

/// La gerarchia richiede di conoscere la materia e l'alunno, e resta al
/// docente. L'app tiene i rientri validi e scrive il markup che rende la
/// mappa navigabile — che a mano nessuno digita.
final class MindmapComposerTests: XCTestCase {

    private let mappa = [
        MindmapNode(title: "Tettonica delle placche", children: [
            MindmapNode(title: "Margini divergenti", detail: "le placche si allontanano", children: [
                MindmapNode(title: "Dorsale oceanica")
            ]),
            MindmapNode(title: "Margini convergenti", detail: "una placca sprofonda sotto l'altra")
        ])
    ]

    /// La proprietà che tiene insieme le due metà.
    func testWritingAndReadingBackGivesTheSameMap() {
        let riletta = MindmapParser.parse(MindmapComposer.compose(mappa))

        XCTAssertEqual(riletta.count, 1)
        XCTAssertEqual(riletta[0].title, "Tettonica delle placche")
        XCTAssertEqual(riletta[0].children.count, 2)
        XCTAssertEqual(riletta[0].children[0].detail, "le placche si allontanano")
        XCTAssertEqual(riletta[0].children[0].children.first?.title, "Dorsale oceanica")
    }

    /// Nessuna intestazione in cima: il lettore usa i titoli come radici, e
    /// un "## Mappa concettuale" diventerebbe il tema principale.
    func testTheMarkupHasNoHeadingThatWouldBecomeARootNode() {
        XCTAssertFalse(MindmapComposer.compose(mappa).contains("#"), MindmapComposer.compose(mappa))
    }

    func testTheIndentIsTwoSpacesPerLevel() {
        let markup = MindmapComposer.compose(mappa)

        XCTAssertTrue(markup.hasPrefix("- Tettonica delle placche"))
        XCTAssertTrue(markup.contains("\n  - Margini divergenti :: le placche si allontanano"))
        XCTAssertTrue(markup.contains("\n    - Dorsale oceanica"))
    }

    // MARK: - La scaletta in lavorazione

    func testFlatRowsBecomeATree() {
        let righe = [
            MindmapDraftRow(title: "Tema", level: 0),
            MindmapDraftRow(title: "Concetto", level: 1),
            MindmapDraftRow(title: "Esempio", level: 2),
            MindmapDraftRow(title: "Secondo concetto", level: 1)
        ]
        let albero = MindmapDraft.nodes(from: righe)

        XCTAssertEqual(albero.count, 1)
        XCTAssertEqual(albero[0].children.count, 2)
        XCTAssertEqual(albero[0].children[0].children.first?.title, "Esempio")
    }

    /// Andata e ritorno: si riapre una mappa che c'è già e la si ritrova
    /// uguale, invece di ricostruirla da capo.
    func testAMapComesBackIntoTheEditorUnchanged() {
        let righe = MindmapDraft.rows(from: mappa)

        XCTAssertEqual(righe.map(\.level), [0, 1, 2, 1])
        // Si confronta il markup e non i nodi: `MindmapNode` porta un id
        // casuale dentro l'uguaglianza, quindi due alberi identici nei
        // contenuti non risultano mai uguali fra loro.
        XCTAssertEqual(MindmapComposer.compose(MindmapDraft.nodes(from: righe)),
                       MindmapComposer.compose(mappa))
    }

    func testEmptyRowsAreSkippedNotWrittenAsBlankNodes() {
        let righe = [
            MindmapDraftRow(title: "Tema", level: 0),
            MindmapDraftRow(title: "   ", level: 1),
            MindmapDraftRow(title: "Concetto", level: 1)
        ]
        XCTAssertEqual(MindmapDraft.nodes(from: righe).first?.children.count, 1)
    }

    /// Un rientro che salta un livello — un dettaglio senza il suo concetto
    /// sopra — si appiattisce invece di far sparire la voce.
    func testAJumpedLevelIsFlattenedNotDropped() {
        let righe = [
            MindmapDraftRow(title: "Tema", level: 0),
            MindmapDraftRow(title: "Salta al terzo", level: 2)
        ]
        let albero = MindmapDraft.nodes(from: righe)

        XCTAssertEqual(albero.count, 1)
        XCTAssertEqual(albero[0].children.first?.title, "Salta al terzo")
    }

    // MARK: - I rientri restano validi

    /// La prima riga non può rientrare: non c'è niente sopra a cui appendersi.
    func testTheFirstRowCannotBeIndented() {
        XCTAssertFalse(MindmapDraft.canIndent([MindmapDraftRow(title: "Tema")], at: 0))
    }

    func testARowCannotGoTwoLevelsDeeperThanTheOneAbove() {
        // Due voci allo stesso livello: la seconda puo' entrare nella prima.
        let pari = [MindmapDraftRow(title: "Tema", level: 0),
                    MindmapDraftRow(title: "Concetto", level: 0)]
        XCTAssertTrue(MindmapDraft.canIndent(pari, at: 1))

        // Ma una voce gia' figlia non puo' scendere ancora: diventerebbe
        // nipote di un nodo che non ha un genitore a quel livello.
        let giaFiglia = [MindmapDraftRow(title: "Tema", level: 0),
                         MindmapDraftRow(title: "Figlio", level: 1)]
        XCTAssertFalse(MindmapDraft.canIndent(giaFiglia, at: 1))
    }

    /// Tre livelli bastano: oltre, su uno schermo, la mappa smette di essere
    /// leggibile a colpo d'occhio.
    func testTheMapStopsAtThreeLevels() {
        let righe = (0...5).map { MindmapDraftRow(title: "Voce \($0)", level: $0) }
        let markup = MindmapComposer.compose(MindmapDraft.nodes(from: righe))

        XCTAssertFalse(markup.contains("      - "), "Nessun rientro oltre il terzo livello:\n\(markup)")
    }

    // MARK: - Nell'app

    @MainActor
    func testTheBuiltMapReachesTheMaterialWithNoEngine() throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.systemModelStatus = .appleIntelligenceOff
        let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")
        vm.addStudent(alunno)

        vm.applyMindmap(mappa)

        XCTAssertEqual(vm.selectedFormat, .conceptMap)
        XCTAssertEqual(MindmapParser.parse(vm.generatedContent).first?.title, "Tettonica delle placche")
        XCTAssertFalse(alunno.lastGeneratedContent.isEmpty, "E resta salvata sulla scheda.")
    }
}
