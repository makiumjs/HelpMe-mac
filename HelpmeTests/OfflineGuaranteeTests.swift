import XCTest

/// La promessa venduta alla scuola non è «non usiamo la rete»: è che il
/// sistema operativo non ce ne dà il permesso. Un DPO la verifica da sé con
/// `codesign -d --entitlements :- HelpMe.app`, e questi test la tengono ferma
/// dal lato nostro — perché reintrodurre l'autorizzazione è una spunta sola
/// nelle capability di Xcode, e nessun altro test se ne accorgerebbe.
final class OfflineGuaranteeTests: XCTestCase {

    /// I test girano dentro Helpme.app: gli entitlement letti qui sono i suoi.
    func testTheAppHasNoPermissionToOpenNetworkConnections() throws {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return XCTFail("Impossibile leggere la firma del processo di test")
        }
        let sandboxed = SecTaskCopyValueForEntitlement(task, "com.apple.security.app-sandbox" as CFString, nil)
        XCTAssertEqual(sandboxed as? Bool, true, "L'app deve restare in App Sandbox")

        let network = SecTaskCopyValueForEntitlement(task, "com.apple.security.network.client" as CFString, nil)
        XCTAssertNil(network, """
        L'app ha di nuovo il permesso di aprire connessioni in uscita. \
        È la garanzia su cui la scuola ha comprato: se serve davvero, va \
        deciso con loro, non riacceso in una capability.
        """)
    }

    /// Seconda serratura, sulla stessa porta: anche con l'entitlement rimesso
    /// per sbaglio, nel sorgente non deve esserci niente che tenti di uscire.
    func testNoSourceFileReachesForTheNetwork() throws {
        let vietati = ["URLSession", "URLRequest", "NWConnection", "CFNetwork", "NSURLConnection"]

        for file in try sourceFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for simbolo in vietati {
                XCTAssertFalse(source.contains(simbolo),
                               "\(file.lastPathComponent) usa \(simbolo): l'app non deve poter uscire.")
            }
        }
    }

    private func sourceFiles() throws -> [URL] {
        let root = URL(fileURLWithPath: #filePath)   // …/HelpmeTests/OfflineGuaranteeTests.swift
            .deletingLastPathComponent()             // …/HelpmeTests
            .deletingLastPathComponent()             // …/Helpme
            .appendingPathComponent("Helpme")

        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        XCTAssertFalse(files.isEmpty, "Non trovo i sorgenti dell'app in \(root.path)")
        return files
    }
}
