import XCTest
import SwiftData
@testable import Helpme

/// Banco di prova per confrontare il modello integrato e Google Gemini
/// sugli stessi testi curricolari.
///
/// Non è un test di regressione: non asserisce nulla sulla qualità, che può
/// giudicare solo un docente. Esegue i due motori sugli stessi prompt e
/// scrive un confronto affiancato da leggere.
///
/// Non parte con la suite normale — richiede rete, API key e Apple
/// Intelligence attiva. Si lancia a mano:
///
///   xcodebuild test -only-testing:HelpmeTests/EngineBenchmarkTests \
///     -destination 'platform=macOS' \
///     GEMINI_API_KEY=... BENCHMARK=1
///
@MainActor
final class EngineBenchmarkTests: XCTestCase {

    /// I testi su cui confrontare i motori. Sostituibili con materiale vero.
    private static let curricularTexts: [(titolo: String, testo: String)] = [
        (
            "Motori a 4 tempi",
            """
            Il motore a combustione interna a quattro tempi compie un ciclo completo in due giri \
            dell'albero motore. Nella fase di aspirazione il pistone scende e la valvola di aspirazione \
            si apre, richiamando nel cilindro la miscela di aria e carburante. Nella compressione \
            entrambe le valvole sono chiuse e il pistone risale comprimendo la miscela, che si riscalda. \
            Allo scoppio la candela innesca la combustione: l'espansione dei gas spinge il pistone verso \
            il basso ed è l'unica fase che produce lavoro. Nello scarico la valvola di scarico si apre e \
            il pistone risalendo espelle i gas combusti. Il rapporto di compressione influisce sul \
            rendimento termodinamico del motore.
            """
        ),
        (
            "Ciclo dell'azoto",
            """
            L'azoto atmosferico non è direttamente assimilabile dalle piante. I batteri azotofissatori, \
            liberi nel terreno o simbionti nei noduli radicali delle leguminose, trasformano l'azoto \
            molecolare in ammoniaca. I batteri nitrificanti ossidano poi l'ammoniaca prima a nitriti e \
            quindi a nitrati, la forma che le radici assorbono. Con la denitrificazione una parte \
            dell'azoto torna in atmosfera. Nelle rotazioni colturali l'inserimento di una leguminosa \
            arricchisce il terreno di azoto e riduce il fabbisogno di concimi di sintesi.
            """
        )
    ]

    /// I formati da mettere alla prova, dal più facile al più impegnativo.
    private static let formats: [DidacticFormat] = [
        .clearExplanation,
        .glossary,
        .conceptMap,
        .interactiveQuiz,
        .equipollenteExam
    ]

    func testCompareEngines() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] == "1",
                          "Banco di prova disattivato. Rilancia con BENCHMARK=1.")

        let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        let systemStatus = SystemModelAvailability.status

        print("\n=== BANCO DI PROVA MOTORI ===")
        print("modello integrato: \(systemStatus)")
        print("api key gemini:    \(apiKey.isEmpty ? "assente" : "presente")\n")

        let context = ModelContext(PersistenceController(inMemory: true).container)
        let viewModel = AppViewModel(modelContext: context)

        // La chiave passa dal blocco amministratore come in produzione: qui
        // si usa una password fissa di prova, coerente da un lancio
        // all'altro sulla stessa macchina di sviluppo.
        let testAdminPassword = "banco-di-prova-locale"
        do {
            try viewModel.adminLock.setInitialPassword(testAdminPassword)
        } catch AdminLock.LockError.passwordAlreadySet {
            try viewModel.adminLock.unlock(testAdminPassword)
        }
        try viewModel.setGeminiApiKey(apiKey)

        let student = StudentProfile(
            name: "Marco Rossi",
            classInfo: "3ª A Agrario",
            programType: .minimi,
            interest: "Meccanica agraria e trattori",
            notes: "DSA con dislessia e discalculia. Ottima comprensione per immagini e schemi pratici. Si stanca sui testi lunghi."
        )
        viewModel.addStudent(student)

        var report = BenchmarkReport()

        for source in Self.curricularTexts {
            for format in Self.formats {
                viewModel.sourceText = source.testo
                viewModel.selectedFormat = format
                let prompt = viewModel.buildPrompt(for: student)

                var run = BenchmarkReport.Run(testo: source.titolo, formato: format.title)

                if systemStatus == .available, #available(macOS 26.0, iOS 26.0, *) {
                    run.systemModel = await Self.execute(
                        service: SystemModelService(),
                        prompt: prompt
                    )
                } else {
                    run.systemModel = .init(esito: "non disponibile: \(systemStatus)", secondi: 0, testo: "")
                }

                if !apiKey.isEmpty {
                    run.gemini = await Self.execute(
                        service: GeminiService(apiKey: apiKey),
                        prompt: prompt
                    )
                } else {
                    run.gemini = .init(esito: "API key assente", secondi: 0, testo: "")
                }

                print("• \(source.titolo) / \(format.title)  —  integrato: \(run.systemModel.riepilogo)  |  gemini: \(run.gemini.riepilogo)")
                report.runs.append(run)
            }
        }

        let url = try report.write()
        print("\nCONFRONTO SCRITTO IN: \(url.path)\n")
    }

    private static func execute(service: LLMInferenceService, prompt: String) async -> BenchmarkReport.Outcome {
        let start = Date()
        do {
            let text = try await service.generateStreaming(prompt: prompt) { _ in }
            return .init(esito: "ok", secondi: Date().timeIntervalSince(start), testo: text)
        } catch {
            return .init(esito: error.localizedDescription, secondi: Date().timeIntervalSince(start), testo: "")
        }
    }
}

// MARK: - Report

struct BenchmarkReport {

    struct Outcome {
        var esito: String
        var secondi: TimeInterval
        var testo: String

        var riepilogo: String {
            esito == "ok"
                ? String(format: "%.1fs, %d caratteri", secondi, testo.count)
                : esito
        }
    }

    struct Run {
        var testo: String
        var formato: String
        var systemModel = Outcome(esito: "non eseguito", secondi: 0, testo: "")
        var gemini = Outcome(esito: "non eseguito", secondi: 0, testo: "")
    }

    var runs: [Run] = []

    /// Scrive il confronto in Markdown, con gli output uno sotto l'altro
    /// per ciascun formato.
    func write() throws -> URL {
        var md = """
        # Confronto motori — HelpMe

        Stesso prompt, stessi testi, due motori. Il giudizio sulla qualità
        didattica spetta al docente: la domanda utile non è "sbaglia?" ma
        "quanto devo correggere prima che mi convenga scriverla da solo?".

        """

        md += "\n## Riepilogo\n\n"
        md += "| Testo | Formato | Modello integrato | Gemini |\n|---|---|---|---|\n"
        for run in runs {
            md += "| \(run.testo) | \(run.formato) | \(run.systemModel.riepilogo) | \(run.gemini.riepilogo) |\n"
        }

        for run in runs {
            md += "\n\n---\n\n## \(run.testo) — \(run.formato)\n"
            md += "\n### Modello integrato nel Mac\n\n"
            md += run.systemModel.testo.isEmpty ? "_\(run.systemModel.esito)_\n" : run.systemModel.testo + "\n"
            md += "\n### Google Gemini\n\n"
            md += run.gemini.testo.isEmpty ? "_\(run.gemini.esito)_\n" : run.gemini.testo + "\n"
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("confronto-motori-helpme.md")
        try md.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
