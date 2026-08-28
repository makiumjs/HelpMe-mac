import Foundation

public protocol LLMInferenceService: Sendable {
    func generateStreaming(prompt: String, onToken: @escaping @Sendable (String) -> Void) async throws -> String
}
