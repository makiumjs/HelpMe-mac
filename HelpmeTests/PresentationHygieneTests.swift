import XCTest

/// Guardia architetturale, non un test di comportamento.
///
/// SwiftUI non presenta in modo affidabile più fogli incatenati sulla stessa
/// vista: ne resta attivo uno e gli altri non si aprono, in silenzio. Il
/// difetto è già costato tre pulsanti morti — «Scrivi il quiz», «Misure PDP»
/// e, sul lato studente, mappa, quiz e traguardi — e nessuno dei 381 test
/// esistenti poteva accorgersene, perché il codice compila e le viste si
/// costruiscono benissimo.
///
/// La cura è una sola proprietà `activeSheet` e un `.sheet(item:)` per vista.
/// Questo test tiene ferma la cura.
final class PresentationHygieneTests: XCTestCase {

    private var viewsDirectory: URL {
        URL(fileURLWithPath: #filePath)      // …/HelpmeTests/PresentationHygieneTests.swift
            .deletingLastPathComponent()     // …/HelpmeTests
            .deletingLastPathComponent()     // …/Helpme
            .appendingPathComponent("Helpme/Views")
    }

    private func swiftFiles() throws -> [URL] {
        let files = FileManager.default.enumerator(at: viewsDirectory, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        XCTAssertFalse(files.isEmpty, "Non trovo i sorgenti delle viste in \(viewsDirectory.path)")
        return files
    }

    /// Nessuna vista deve presentare più di un pannello per volta.
    func testNoViewChainsTwoPresentationsOfTheSameKind() throws {
        for file in try swiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)

            for modifier in [".sheet(", ".popover(", ".fileImporter(", ".fileExporter(", ".alert("] {
                let count = source.components(separatedBy: modifier).count - 1
                XCTAssertLessThanOrEqual(count, 1, """
                \(file.lastPathComponent) usa \(modifier) \(count) volte. \
                SwiftUI ne presenta uno solo e gli altri restano muti: usa una \
                proprietà sola e \(modifier)item:) con uno switch.
                """)
            }
        }
    }

    /// Un pannello che si apre da più di un punto va presentato una volta
    /// sola, da una vista che è sempre sullo schermo. «Scrivi il quiz» non si
    /// apriva perché il suo foglio stava sulla schermata d'ingresso, che
    /// compare solo quando non c'è ancora nessun alunno.
    func testEveryPresentedSheetIsDrivenByAnActiveSheetProperty() throws {
        for file in try swiftFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            guard source.contains(".sheet(") else { continue }

            XCTAssertTrue(source.contains(".sheet(item:"), """
            \(file.lastPathComponent) presenta un foglio con isPresented. \
            Serve .sheet(item:) su una proprietà activeSheet, altrimenti \
            aggiungerne un secondo lo rende muto senza che niente lo segnali.
            """)
        }
    }
}
