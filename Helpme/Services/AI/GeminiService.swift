import Foundation

public enum GeminiError: LocalizedError {
    case missingApiKey
    case invalidApiKey(String?)
    case quotaExceeded(String?)
    case modelNotFound(String)
    case blockedByPolicy(String)
    case emptyResponse
    case network(URLError)
    case server(status: Int, message: String?)

    public var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Manca la API key di Google Gemini. Inseriscila nelle impostazioni (icona con i cursori, in alto a destra)."

        case .invalidApiKey(let detail):
            return "La API key non è stata accettata da Google. Controlla di averla copiata per intero."
                + (detail.map { " Dettaglio: \($0)" } ?? "")

        case .quotaExceeded(let detail):
            return "Quota Google Gemini esaurita. Riprova più tardi o verifica i limiti del tuo account."
                + (detail.map { " Dettaglio: \($0)" } ?? "")

        case .modelNotFound(let model):
            return "Il modello \"\(model)\" non è disponibile per questa API key."

        case .blockedByPolicy(let reason):
            return "Google ha bloccato la risposta (\(reason)). Prova a riformulare il testo di partenza."

        case .emptyResponse:
            return "Google ha risposto senza contenuto. Riprova, eventualmente accorciando il testo di partenza."

        case .network(let error):
            switch error.code {
            case .notConnectedToInternet:
                return "Nessuna connessione a Internet."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                // Sintomo tipico della sandbox senza permesso di rete in uscita.
                return "Impossibile raggiungere i server di Google. Controlla la connessione; se il problema persiste, l'app potrebbe non avere il permesso di accedere alla rete."
            case .timedOut:
                return "Google non ha risposto in tempo. Riprova, eventualmente con un testo più corto."
            default:
                return "Errore di rete: \(error.localizedDescription)"
            }

        case .server(let status, let message):
            return "Errore dal server Google (codice \(status))."
                + (message.map { " \($0)" } ?? "")
        }
    }
}

public final class GeminiService: LLMInferenceService, @unchecked Sendable {

    private let apiKey: String
    private let modelName: String
    private let session: URLSession

    public init(apiKey: String, modelName: String = "gemini-2.0-flash") {
        self.apiKey = apiKey
        self.modelName = modelName

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }

    public func generateStreaming(prompt: String, onToken: @escaping @Sendable (String) -> Void) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GeminiError.missingApiKey }

        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):streamGenerateContent")
        components?.queryItems = [
            URLQueryItem(name: "alt", value: "sse")
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")

        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 4096
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch let error as URLError {
            throw GeminiError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 4000 { break }
            }
            throw Self.error(status: http.statusCode, body: body, model: modelName)
        }

        var fullText = ""
        var blockReason: String?

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payloadText = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard payloadText != "[DONE]",
                  let data = payloadText.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            if let feedback = json["promptFeedback"] as? [String: Any],
               let reason = feedback["blockReason"] as? String {
                blockReason = reason
            }

            guard let candidates = json["candidates"] as? [[String: Any]],
                  let candidate = candidates.first else { continue }

            if let finish = candidate["finishReason"] as? String,
               finish != "STOP", finish != "MAX_TOKENS" {
                blockReason = finish
            }

            if let content = candidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String {
                        fullText += text
                        onToken(text)
                    }
                }
            }
        }

        if fullText.isEmpty {
            if let blockReason { throw GeminiError.blockedByPolicy(blockReason) }
            throw GeminiError.emptyResponse
        }

        return fullText
    }

    static func error(status: Int, body: String, model: String) -> GeminiError {
        let message = parseErrorMessage(from: body)

        switch status {
        case 400 where (message?.localizedCaseInsensitiveContains("api key") ?? false),
             401, 403:
            return .invalidApiKey(message)
        case 404:
            return .modelNotFound(model)
        case 429:
            return .quotaExceeded(message)
        default:
            return .server(status: status, message: message)
        }
    }

    static func parseErrorMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8) else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
        }
     
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let error = array.first?["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return nil
    }
}
