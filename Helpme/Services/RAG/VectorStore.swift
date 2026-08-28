import Foundation
import Accelerate

public nonisolated struct DocumentChunk: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var documentTitle: String
    public var text: String
    public var embedding: [Float]
    public var pageNumber: Int?
    
    public init(id: UUID = UUID(), documentTitle: String, text: String, embedding: [Float] = [], pageNumber: Int? = nil) {
        self.id = id
        self.documentTitle = documentTitle
        self.text = text
        self.embedding = embedding
        self.pageNumber = pageNumber
    }
}

public nonisolated final class VectorStore: @unchecked Sendable {
    private var chunks: [DocumentChunk] = []
    private let lock = NSLock()
    
    public init() {}
    
    public func add(chunks newChunks: [DocumentChunk]) {
        lock.lock()
        defer { lock.unlock() }
        chunks.append(contentsOf: newChunks)
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        chunks.removeAll()
    }

    /// Rimuove i frammenti di un solo documento, lasciando intatti gli altri.
    @discardableResult
    public func removeChunks(ofDocument title: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let before = chunks.count
        chunks.removeAll { $0.documentTitle == title }
        return before - chunks.count
    }
    
    public func allChunks() -> [DocumentChunk] {
        lock.lock()
        defer { lock.unlock() }
        return chunks
    }
    
    /// Calcolo Cosine Similarity accelerato via Apple Accelerate (vDSP)
    public static func cosineSimilarity(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        
        var dotProduct: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        
        var magA: Float = 0.0
        vDSP_svesq(a, 1, &magA, vDSP_Length(a.count))
        magA = sqrt(magA)
        
        var magB: Float = 0.0
        vDSP_svesq(b, 1, &magB, vDSP_Length(b.count))
        magB = sqrt(magB)
        
        guard magA > 0 && magB > 0 else { return 0.0 }
        return dotProduct / (magA * magB)
    }
    
    public func search(queryEmbedding: [Float], topK: Int = 3) -> [(chunk: DocumentChunk, score: Float)] {
        lock.lock()
        defer { lock.unlock() }
        
        let scored = chunks.map { chunk -> (chunk: DocumentChunk, score: Float) in
            let score = VectorStore.cosineSimilarity(a: queryEmbedding, b: chunk.embedding)
            return (chunk, score)
        }
        
        return scored
            .sorted(by: { $0.score > $1.score })
            .prefix(topK)
            .map { $0 }
    }
}
