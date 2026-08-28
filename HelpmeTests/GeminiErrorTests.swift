import XCTest
@testable import Helpme

/// Prima gli errori dell'API arrivavano come "Status Code: 400" e il motivo
/// vero — che sta nel corpo della risposta — veniva buttato via.
@MainActor
final class GeminiErrorTests: XCTestCase {

    private let invalidKeyBody = """
    {"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}
    """

    func testInvalidApiKeyIsRecognized() {
        let error = GeminiService.error(status: 400, body: invalidKeyBody, model: "gemini-2.0-flash")
        guard case .invalidApiKey = error else { return XCTFail("atteso invalidApiKey, ottenuto \(error)") }
        let text = try? XCTUnwrap(error.errorDescription)
        XCTAssertTrue(text?.contains("API key") ?? false)
    }

    func testQuotaExceededIsRecognized() {
        let body = """
        {"error":{"code":429,"message":"Quota exceeded for quota metric.","status":"RESOURCE_EXHAUSTED"}}
        """
        let error = GeminiService.error(status: 429, body: body, model: "gemini-2.0-flash")
        guard case .quotaExceeded = error else { return XCTFail("atteso quotaExceeded") }
        XCTAssertTrue(error.errorDescription?.contains("Quota") ?? false)
    }

    func testUnknownModelIsRecognized() {
        let error = GeminiService.error(status: 404, body: "{}", model: "gemini-inesistente")
        guard case .modelNotFound = error else { return XCTFail("atteso modelNotFound") }
        XCTAssertTrue(error.errorDescription?.contains("gemini-inesistente") ?? false)
    }

    func testServerMessageIsSurfaced() {
        let body = """
        {"error":{"code":500,"message":"Internal error encountered."}}
        """
        let error = GeminiService.error(status: 500, body: body, model: "gemini-2.0-flash")
        XCTAssertTrue(error.errorDescription?.contains("Internal error encountered") ?? false,
                      "il messaggio del server deve arrivare all'utente")
    }

    func testErrorMessageIsParsedFromArrayResponse() {
        // Lo streaming a volte risponde con un array di oggetti.
        let body = """
        [{"error":{"code":400,"message":"Richiesta malformata."}}]
        """
        XCTAssertEqual(GeminiService.parseErrorMessage(from: body), "Richiesta malformata.")
    }

    func testMalformedBodyDoesNotCrash() {
        XCTAssertNil(GeminiService.parseErrorMessage(from: "non è json"))
        XCTAssertNil(GeminiService.parseErrorMessage(from: ""))
        let error = GeminiService.error(status: 503, body: "<html>gateway</html>", model: "m")
        XCTAssertNotNil(error.errorDescription)
    }

    func testMissingKeyTellsWhereToPutIt() async {
        let service = GeminiService(apiKey: "   ")
        do {
            _ = try await service.generateStreaming(prompt: "x") { _ in }
            XCTFail("doveva fallire")
        } catch let error as GeminiError {
            guard case .missingApiKey = error else { return XCTFail("atteso missingApiKey") }
            XCTAssertTrue(error.errorDescription?.contains("impostazioni") ?? false,
                          "il messaggio deve dire dove inserirla")
        } catch {
            XCTFail("errore inatteso: \(error)")
        }
    }

    /// Il caso che si è appena verificato: sandbox senza permesso di rete.
    func testBlockedNetworkGivesActionableMessage() {
        let error = GeminiError.network(URLError(.cannotFindHost))
        let text = error.errorDescription ?? ""
        XCTAssertTrue(text.contains("permesso"), "deve suggerire il permesso di rete: \(text)")
    }
}
