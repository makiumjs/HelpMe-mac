import Testing
import SwiftData
@testable import Helpme

/// Il confine che `StudentPseudonymizer` non copre: il testo che il docente
/// incolla, e i frammenti indicizzati, entrano nella richiesta com'è.
/// Trovato dalla controparte Windows il 30 agosto 2026.
struct SourceTextScreeningTests {

    private let alunno = StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA")

    @Test func unaVerificaDiMatematicaNonFaScattareNiente() {
        let esito = SourceTextScreening.of(
            sourceText: "Calcola l'area del triangolo di base 6 cm e altezza 4 cm.",
            student: alunno)

        #expect(!esito.hasFindings)
        #expect(esito.warning == nil)
    }

    @Test func ilNomeDellAlunnoNelTestoVieneRiconosciuto() {
        let esito = SourceTextScreening.of(
            sourceText: "Andrea Pirlo ha svolto la prova con tempi aggiuntivi.",
            student: alunno)

        #expect(esito.reasons.contains("contiene il nome dell'alunno"))
    }

    /// L'avviso deve dire *quali* termini: un cartello generico si impara a
    /// ignorare.
    @Test func lAvvisoCitaITerminiRiconosciuti() throws {
        let esito = SourceTextScreening.of(
            sourceText: "Diagnosi di dislessia con certificazione ai sensi della legge 104.",
            student: nil)

        let avviso = try #require(esito.warning)
        #expect(avviso.contains("«diagnos»"))
        #expect(avviso.contains("riferimenti clinici"))
    }

    /// Un cognome di due lettere scatterebbe a ogni riga, e un avviso che
    /// scatta sempre non lo legge più nessuno.
    @Test func leParoleTroppoCorteDelNomeNonScattano() {
        let re = StudentProfile(name: "Ada Re", classInfo: "2B")
        let esito = SourceTextScreening.of(
            sourceText: "Il re governava con l'aiuto dei funzionari.",
            student: re)

        #expect(!esito.reasons.contains("contiene il nome dell'alunno"))
    }

    /// Un PEI indicizzato mesi prima uscirebbe altrimenti senza che nessuno
    /// lo colleghi a questa generazione.
    @Test func iFrammentiIndicizzatiVengonoControllati() {
        let esito = SourceTextScreening.of(
            sourceText: "Il ciclo dell'acqua.",
            student: alunno,
            indexedExcerpts: ["Andrea Pirlo — PEI 2026, diagnosi di dislessia."])

        #expect(esito.reasons.count == 2)
        #expect(esito.warning?.contains("documento indicizzato") == true)
    }

    @Test func unTestoVuotoNonProduceAvvisi() {
        #expect(!SourceTextScreening.of(sourceText: "   ", student: alunno).hasFindings)
    }

    // MARK: - Nell'app

    @MainActor
    private func viewModel() throws -> AppViewModel {
        let container = try ModelContainer(
            for: StudentProfile.self, GloLogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = AppViewModel(modelContext: ModelContext(container))
        vm.addStudent(StudentProfile(name: "Andrea Pirlo", classInfo: "1ITA"))
        return vm
    }

    /// Il controllo sta sulla strada della generazione, non solo accanto al
    /// pulsante: la strada non si aggira passando da un'altra parte.
    @Test func versoIlCloudSenzaConfermaLaGenerazioneSiFerma() throws {
        let esito = SourceTextScreening.of(
            sourceText: "Andrea Pirlo, diagnosi di dislessia.", student: alunno)

        let bloccante = try #require(SourceTextScreening.blockingMessage(
            screening: esito, reviewed: false, goesToCloud: true))
        #expect(bloccante.contains("conferma e procedi"))

        #expect(SourceTextScreening.blockingMessage(
            screening: esito, reviewed: true, goesToCloud: true) == nil)
        #expect(SourceTextScreening.blockingMessage(
            screening: esito, reviewed: false, goesToCloud: false) == nil)
    }

    /// Senza chiave Gemini non esce niente dal Mac, quindi non si avvisa: un
    /// avviso che scatta quando non serve insegna a ignorarlo.
    @MainActor
    @Test func senzaChiaveNienteEsceEQuindiNonSiAvvisa() throws {
        let vm = try viewModel()
        vm.selectedFormat = .clearExplanation
        vm.engineOverride = .gemini

        #expect(!vm.usesRemoteModel)
    }

    /// Ma sui formati che si compongono in locale non esce niente, quindi
    /// avvisare insegnerebbe solo a ignorare l'avviso.
    @MainActor
    @Test func laComposizioneLocaleNonAvvisa() async throws {
        let vm = try viewModel()
        vm.systemModelStatus = .appleIntelligenceOff
        vm.selectedFormat = .glossary
        vm.sourceText = "Andrea Pirlo, diagnosi di dislessia. La litosfera è lo strato rigido esterno."

        #expect(!vm.usesRemoteModel)
        await vm.generateMaterial()

        #expect(vm.errorMessage == nil)
        #expect(!vm.generatedContent.isEmpty)
    }

    /// Una conferma data su un altro testo non vale su questo.
    @MainActor
    @Test func laConfermaDecadeQuandoIlTestoCambia() throws {
        let vm = try viewModel()
        vm.sourceText = "Diagnosi di dislessia."
        vm.confirmSourceTextReviewed()
        #expect(vm.sourceTextReviewed)

        vm.sourceText = "Un altro testo, con un'altra diagnosi."
        #expect(!vm.sourceTextReviewed)
    }

    @MainActor
    @Test func laConfermaDecadeQuandoCambiaAlunno() throws {
        let vm = try viewModel()
        vm.sourceText = "Diagnosi di dislessia."
        vm.confirmSourceTextReviewed()

        vm.addStudent(StudentProfile(name: "Giulia Bianchi", classInfo: "2B"))
        #expect(!vm.sourceTextReviewed)
    }
}
