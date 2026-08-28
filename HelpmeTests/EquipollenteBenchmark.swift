import XCTest
import SwiftData
@testable import Helpme

/// Banco di misura temporaneo: genera una verifica equipollente vera,
/// passando dal percorso reale dell'app (stesso prompt, stessa
/// pseudonimizzazione, stesso servizio), e misura quanto ci mette.
///
/// Non è un test — fa una chiamata di rete a pagamento e dipende da una
/// chiave — infatti si salta da solo se la chiave non c'è. Va rimosso a
/// misurazione finita.
@MainActor
final class EquipollenteBenchmark: XCTestCase {

    /// La cartella temporanea del contenitore: i test girano in sandbox,
    /// quindi chiave in ingresso e risultati in uscita passano da qui.
    private static var workingDirectory: URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private var apiKey: String? {
        let url = Self.workingDirectory.appendingPathComponent("gemini-key.txt")
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    private let curricularText = """
    VERIFICA DI MECCANICA AGRARIA
    Classe 3ª A — Indirizzo Agrario
    Il motore a combustione interna e la trattrice agricola

    PARTE PRIMA — Domande aperte (punti 12)

    1. Descrivi il ciclo di funzionamento di un motore a quattro tempi, specificando per \
    ciascuna fase la posizione del pistone, lo stato delle valvole di aspirazione e di \
    scarico, e quale fase produce lavoro utile. (punti 5)

    2. Spiega la differenza tra un motore ad accensione comandata (ciclo Otto) e uno ad \
    accensione spontanea (ciclo Diesel), indicando quale dei due è prevalentemente \
    impiegato nelle trattrici agricole e per quali ragioni tecniche ed economiche. (punti 4)

    3. Illustra la funzione del filtro dell'aria in un motore diesel agricolo e descrivi \
    le conseguenze di una manutenzione trascurata su questo componente. (punti 3)

    PARTE SECONDA — Problema applicativo (punti 6)

    Una trattrice con motore diesel da 90 kW di potenza nominale lavora per 6 ore \
    consecutive in aratura, mantenendo un regime pari all'80% della potenza nominale. \
    Sapendo che il consumo specifico è di 240 g/kWh e che la densità del gasolio agricolo \
    è di 0,84 kg/litro:
    a) calcola la potenza effettivamente erogata;
    b) calcola il consumo totale di gasolio in kg;
    c) converti il consumo in litri e stima il costo dell'operazione, considerando un \
    prezzo di 0,95 €/litro.

    PARTE TERZA — Terminologia tecnica (punti 4)

    Definisci brevemente i seguenti termini: cilindrata, rapporto di compressione, \
    coppia motrice, presa di potenza (PTO).

    Tempo a disposizione: 60 minuti. È consentito l'uso della calcolatrice non programmabile.
    """

    /// Il motore da misurare: si preferisce quello integrato nel Mac,
    /// perche non costa niente e non manda dati fuori — ed e anche la
    /// risposta empirica alla domanda se un modello da ~3B regga il formato
    /// piu impegnativo dell'app. Gemini resta come alternativa.
    private func chooseEngine() throws -> (name: String, service: LLMInferenceService) {
        if SystemModelAvailability.status == .available, #available(macOS 26.0, iOS 26.0, *) {
            return ("modello integrato nel Mac (~3B, on-device)", SystemModelService())
        }
        if let apiKey {
            return ("Google Gemini", GeminiService(apiKey: apiKey))
        }
        throw XCTSkip("""
        Nessun motore disponibile.
        Modello integrato: \(SystemModelAvailability.status)
        Chiave Gemini attesa in: \(Self.workingDirectory.appendingPathComponent("gemini-key.txt").path)
        """)
    }

    func testGenerateEquipollenteAndMeasure() async throws {
        let engine = try chooseEngine()

        // Percorso reale dell'app: stesso view model, stesso formato, stesso prompt.
        let viewModel = AppViewModel(modelContext: .init(PersistenceController(inMemory: true).container))
        viewModel.selectedFormat = .equipollenteExam
        viewModel.sourceText = curricularText

        let student = StudentProfile(
            name: "Marco Rossi",
            classInfo: "3ª A Agrario",
            programType: .minimi,
            interest: "Meccanica agraria e trattori d'epoca",
            notes: "Ottima comprensione per immagini e schemi pratici. Fatica sulla scrittura estesa e sui testi lunghi. Buone competenze di calcolo se il problema è scomposto in passaggi."
        )

        let prompt = viewModel.buildPrompt(for: student)

        // Il confine di privacy vale anche in laboratorio: se questo saltasse,
        // staremmo misurando una configurazione che non spediremmo mai.
        XCTAssertFalse(prompt.contains("Marco Rossi"), "Il nome non deve lasciare il Mac")
        XCTAssertFalse(prompt.contains("3ª A"), "La sezione non deve lasciare il Mac")

        let service = engine.service

        var firstTokenAt: Date? = nil
        let start = Date()

        let result = try await service.generateStreaming(prompt: prompt) { _ in
            if firstTokenAt == nil { firstTokenAt = Date() }
        }

        let elapsed = Date().timeIntervalSince(start)
        let latency = firstTokenAt.map { $0.timeIntervalSince(start) } ?? elapsed
        let restored = StudentPseudonymizer.restoreIdentity(in: result, name: student.name)

        // Stima grossolana: in italiano un token vale ~4 caratteri.
        let promptTokens = prompt.count / 4
        let outputTokens = restored.count / 4

        // La domanda che conta non e solo "quanto ci mette" ma "il
        // materiale e utilizzabile": se il modello non rispetta il formato,
        // a valle mappa e quiz restano testo morto.
        let quiz = QuizParser.parse(restored)
        let mindmap = MindmapParser.parse(restored)
        let hasGrid = restored.contains("|") && restored.lowercased().contains("griglia")

        let report = """
        ══════════════════════════════════════════════════════
        MISURA — generazione verifica equipollente
        ══════════════════════════════════════════════════════
        Motore                         \(engine.name)
        Attesa prima del primo token   \(String(format: "%.1f", latency)) s
        Tempo totale di generazione    \(String(format: "%.1f", elapsed)) s
        Prompt inviato                 ~\(promptTokens) token (\(prompt.count) caratteri)
        Materiale prodotto             ~\(outputTokens) token (\(restored.count) caratteri)
        Costo stimato (se Gemini)      ~\(String(format: "%.4f", Double(promptTokens) * 0.0000001 + Double(outputTokens) * 0.0000004)) €
        ──────────────────────────────────────────────────────
        Il materiale prodotto e usabile dall'app?
        Griglia di valutazione         \(hasGrid ? "sì, come tabella" : "NO — assente o non tabellare")
        Domande leggibili dal quiz     \(quiz.count)
        Nodi leggibili dalla mappa     \(mindmap.count)
        ══════════════════════════════════════════════════════
        """

        print(report)

        try report.write(
            to: Self.workingDirectory.appendingPathComponent("misura.txt"),
            atomically: true, encoding: .utf8)
        try prompt.write(
            to: Self.workingDirectory.appendingPathComponent("prompt-inviato.txt"),
            atomically: true, encoding: .utf8)
        try restored.write(
            to: Self.workingDirectory.appendingPathComponent("verifica-generata.md"),
            atomically: true, encoding: .utf8)

        XCTAssertFalse(restored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "\(engine.name) non ha restituito nulla")
    }
}
