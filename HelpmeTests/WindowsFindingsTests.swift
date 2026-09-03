import Testing
import SwiftData
@testable import Helpme

/// Rilievi trovati dalla controparte Windows il 1 settembre 2026, su
/// verifiche scritte come le scrive un docente. Quasi tutti sono usciti
/// guardando il documento prodotto, con i test verdi.
struct WindowsFindingsTests {

    // MARK: - Il riconoscitore

    /// Word converte da solo "1 - " in "1 – " e "--" in "—", mentre il
    /// docente scrive e senza che se ne accorga.
    @Test func leLineetteCheWordMetteAlPostoTuo() {
        for riga in ["1 - Descrivi il ciclo.", "1 – Descrivi il ciclo.", "1 — Descrivi il ciclo."] {
            #expect(ExamParser.questionStart(in: riga) != nil, "\(riga)")
        }
        #expect(ExamParser.questionStart(in: "5 - 3 = 2") == nil)
    }

    /// Metà delle consegne non è una domanda: finiscono con il punto. Senza
    /// questo, una verifica senza numeri scritta all'imperativo valeva zero
    /// quesiti e l'app non faceva niente senza dire perché.
    @Test func leConsegneAllImperativoSenzaNumerazione() {
        let esame = ExamParser.parse("""
        Verifica di Scienze

        Descrivi la struttura interna della Terra.
        Elenca i tre tipi di margine fra due placche.
        Spiega perché la faglia di Sant'Andrea è trasforme.
        """)

        #expect(esame.questions.count == 3)
        #expect(esame.questions[0].text.hasPrefix("Descrivi"))
    }

    /// "Leggi con attenzione il brano seguente" non è un quesito.
    @Test func leRigheDiServizioNonDiventanoQuesiti() {
        let esame = ExamParser.parse("""
        Leggi con attenzione il brano seguente.
        Osserva la figura 3.

        Descrivi il fenomeno rappresentato.
        """)
        #expect(esame.questions.count == 1)
    }

    /// La terza persona dell'indicativo non è un imperativo: ogni frase di un
    /// brano da leggere diventerebbe un quesito.
    @Test func laProsaNonDiventaUnaVerifica() {
        #expect(!ExamParser.isAssignment("La crosta copre il mantello."))
        #expect(!ExamParser.isAssignment("Il magma risale e solidifica."))
        #expect(ExamParser.isAssignment("Descrivi il ciclo."))
    }

    /// Una verifica mescola spesso quesiti numerati e consegne senza numero.
    /// Finché la ricaduta era tutto-o-niente, bastava un solo numerato per
    /// perdere tutti gli altri: qui ne restava uno su cinque.
    @Test func unaVerificaCheMescolaNumeratiEImperativiLiTieneTutti() {
        let esame = ExamParser.parse("""
        Descrivi la struttura interna della Terra. punti 3
        Elenca i tre tipi di margine fra due placche.
        1 — Spiega perché la faglia è trasforme.
        Calcola la distanza dell'epicentro. ____ /3
        """)

        #expect(esame.questions.count == 4)
        #expect(esame.questions.map(\.number) == ["1", "2", "3", "4"])
        #expect(esame.questions[0].points == 3)
        #expect(esame.questions[3].points == 3)
    }

    @Test func treNotazioniDiPunteggioInPiu() {
        #expect(ExamParser.points(in: "Descrivi il ciclo. punti 2") == 2)
        #expect(ExamParser.points(in: "Calcola la potenza. ____ /3") == 3)
        // In una verifica di matematica "Calcola 6/2" non perde il divisore.
        #expect(ExamParser.points(in: "Calcola 6/2") == nil)
    }

    @Test func veroFalsoSenzaBarra() {
        #expect(ExamParser.isTrueFalseMarker("Segna con una crocetta V o F."))
        #expect(ExamParser.isTrueFalseMarker("La crosta è più densa.  V  F"))
        #expect(!ExamParser.isTrueFalseMarker("Descrivi il ciclo."))
    }

    // MARK: - Le due decisioni allineate a Windows

    /// Comporre una scheda PDP è produrre materiale nuovo, ed è il prodotto
    /// che la scuola compra: ora che sei formati su sette non usano il
    /// modello, lasciarli passare vorrebbe dire che la licenza non protegge
    /// quasi più niente. I tre pannelli scrivono nel materiale senza passare
    /// da `generateMaterial`, quindi il controllo va anche lì.
    @MainActor
    @Test func unaLicenzaScadutaFermaAncheIPannelli() throws {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        vm.licenseState = .expired(License(school: "I.I.S.", issuedOn: .distantPast, expiresOn: .distantPast))

        vm.applyQuiz([QuizQuestion(prompt: "Domanda?", options: [
            QuizOption(text: "A", isCorrect: true, explanation: nil),
            QuizOption(text: "B", isCorrect: false, explanation: nil)
        ])])
        #expect(vm.generatedContent.isEmpty)

        vm.applyMindmap([MindmapNode(title: "Tema")])
        #expect(vm.generatedContent.isEmpty)

        vm.applySimplifiedText("Testo riscritto.", rewritten: 1, gulpease: 70)
        #expect(vm.generatedContent.isEmpty)
        #expect(vm.errorMessage?.contains("scaduta") == true)
    }

    /// La spiegazione semplificata è l'unico formato dove un modello fa
    /// qualcosa che l'app non sa fare: riscrivere le parole. Per gli altri sei
    /// la composizione è migliore, non un ripiego.
    @Test func soloLaSpiegazionePreferisceIlModello() {
        #expect(DidacticFormat.clearExplanation.prefersModelWhenAvailable)
        for formato in DidacticFormat.allCases where formato != .clearExplanation {
            #expect(!formato.prefersModelWhenAvailable, "\(formato.rawValue)")
        }
    }

    /// E siccome ora ci va da sé, la sorveglianza del testo di partenza deve
    /// scattare anche lì.
    // MARK: - Il documento prodotto

    private func foglio(_ testo: String) -> String {
        EquipollenteComposer.compose(.init(
            studentName: "Andrea Pirlo", classInfo: "1ITA",
            programTitle: ProgramType.minimi.localizedTitle,
            compensatory: [], dispensatory: [],
            exam: ExamParser.parse(testo)))
    }

    /// La struttura su cui si risponde può non essere arrivata: era
    /// un'immagine, stava su un allegato. Allo studente arrivava la consegna
    /// seguita dal nulla.
    @Test func unVeroFalsoSenzaAffermazioniRiceveComunqueLeRighe() {
        let testo = foglio("1. Indica se le seguenti affermazioni sono vere o false.")

        #expect(testo.contains("_______"))
        #expect(testo.contains("annuncia affermazioni o una tabella"))
        #expect(testo.contains("Il quesito 1"))
    }

    /// Ma dove la struttura c'è, le righe non servono: si risponde dentro.
    @Test func doveLaStrutturaCeLeRigheNonServono() {
        let testo = foglio("""
        1. Indica se le seguenti affermazioni sono vere o false:
           • La crosta oceanica è più densa.  V  F
        """)
        #expect(!testo.contains("_______________________________________________"))
    }

    /// Il nome della struttura è più specifico del verbo che la riempie.
    @Test func nellaGrigliaLaStrutturaVinceSulVerbo() {
        let quesito = ExamQuestion(
            number: "1",
            text: "Completa la tabella con i tre tipi di margine:\n| Zona | Margine |\n|---|---|")

        #expect(EquipollenteComposer.indicator(for: quesito).contains("tabella"))
    }

    /// "I quesiti 2, 3 sono arrivati" non è italiano: l'ultimo si lega con «e».
    @Test func lElencoDeiQuesitiSiLegaConLaCongiunzione() {
        #expect(EquipollenteComposer.italianList(["2"]) == "2")
        #expect(EquipollenteComposer.italianList(["2", "3"]) == "2 e 3")
        #expect(EquipollenteComposer.italianList(["2", "3", "5"]) == "2, 3 e 5")
    }

    /// Le caselle non compilate finiscono nel documento come righe cliccabili
    /// vuote. L'andata e ritorno torna giusto lo stesso, perché il parser le
    /// scarta in lettura: un test di round-trip qui non dice niente.
    @Test func leOpzioniVuoteDelQuizNonFinisconoNelDocumento() {
        let markup = QuizComposer.compose([QuizQuestion(prompt: "Quale fase produce lavoro?", options: [
            QuizOption(text: "Espansione", isCorrect: true, explanation: nil),
            QuizOption(text: "Scarico", isCorrect: false, explanation: nil),
            QuizOption(text: "   ", isCorrect: false, explanation: nil)
        ])])

        #expect(!markup.contains("- [ ]  \n"))
        #expect(markup.components(separatedBy: "- [").count - 1 == 2)
    }

    /// Con NLTagger il Mac tiene solo i sostantivi: gli avverbi in -mente e
    /// gli aggettivi comuni non dovrebbero uscire accanto a «litosfera».
    @Test func gliAvverbiNonSonoTerminiDiGlossario() {
        let termini = GlossaryExtractor.extract(from: """
        La litosfera è parzialmente rigida nello strato esterno. La litosfera
        si comporta diversamente dall'astenosfera, che è notevolmente plastica.
        """).map(\.term)

        for parola in ["parzialmente", "diversamente", "notevolmente"] {
            #expect(!termini.contains(parola), "«\(parola)» non è un termine da spiegare: \(termini)")
        }
    }
}
