import Foundation

/// Un documento presente nell'indice, come lo vede il docente.
/// Esito di un'importazione: quanto e' finito nell'indice, e il testo
/// estratto, che il docente puo' volersi ritrovare nell'editor.
public nonisolated struct ImportedDocument: Sendable {
    public let title: String
    public let text: String
    public let chunkCount: Int
}

public nonisolated struct IndexedDocument: Identifiable, Sendable, Equatable {
    public var id: String { title }
    public let title: String
    public let chunkCount: Int

    public init(title: String, chunkCount: Int) {
        self.title = title
        self.chunkCount = chunkCount
    }
}

public nonisolated final class SemanticSearchService: @unchecked Sendable {
    private let vectorStore: VectorStore
    private let indexer: DocumentIndexer

    public init(vectorStore: VectorStore = VectorStore(), indexer: DocumentIndexer = DocumentIndexer()) {
        self.vectorStore = vectorStore
        self.indexer = indexer
    }

    // MARK: - Indicizzazione

    /// Indicizza un documento scelto dal docente.
    ///
    /// L'URL arriva dal selettore di file di sistema, quindi è fuori dalla
    /// sandbox dell'app: l'accesso va aperto e richiuso esplicitamente,
    /// altrimenti la lettura fallisce con un errore di permessi.
    @discardableResult
    public func indexDocument(url: URL, title: String? = nil) throws -> Int {
        try importDocument(url: url, title: title).chunkCount
    }

    /// Come `indexDocument`, ma restituisce anche il testo estratto.
    ///
    /// Serve perche' indicizzare non basta: il docente che importa la lezione
    /// vuole adattare *quella*, e finora il testo spariva nell'indice mentre
    /// l'editor restava vuoto. Si estrae una volta sola.
    public func importDocument(url: URL, title: String? = nil) throws -> ImportedDocument {
        let docTitle = title ?? url.deletingPathExtension().lastPathComponent

        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer { if needsScopedAccess { url.stopAccessingSecurityScopedResource() } }

        let text = try indexer.extractText(from: url)
        let chunks = indexer.chunkText(text: text, title: docTitle)

        guard !chunks.isEmpty else {
            throw NSError(domain: "SemanticSearchService", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "\(url.lastPathComponent) è stato letto ma non conteneva testo utilizzabile."
            ])
        }

        // Reindicizzare lo stesso documento lo sostituisce invece di
        // duplicarne i frammenti nei risultati della ricerca.
        vectorStore.removeChunks(ofDocument: docTitle)
        vectorStore.add(chunks: chunks)
        return ImportedDocument(title: docTitle, text: text, chunkCount: chunks.count)
    }

    @discardableResult
    public func indexRawText(text: String, title: String = "Testo Didattico") -> Int {
        let chunks = indexer.chunkText(text: text, title: title)
        vectorStore.removeChunks(ofDocument: title)
        vectorStore.add(chunks: chunks)
        return chunks.count
    }

    // MARK: - Ricerca

    public func searchRelevantContext(query: String, topK: Int = 3) -> [DocumentChunk] {
        let queryEmbedding = DocumentIndexer.embedding(for: query)
        let results = vectorStore.search(queryEmbedding: queryEmbedding, topK: topK)
        return results.map { $0.chunk }
    }

    // MARK: - Stato dell'indice

    public func clearIndex() {
        vectorStore.clear()
    }

    @discardableResult
    public func removeDocument(title: String) -> Int {
        vectorStore.removeChunks(ofDocument: title)
    }

    public var indexedChunksCount: Int {
        vectorStore.allChunks().count
    }

    /// I documenti nell'indice, nell'ordine in cui sono stati aggiunti:
    /// serve a mostrare al docente che cosa l'IA può davvero consultare.
    public var indexedDocuments: [IndexedDocument] {
        var order: [String] = []
        var counts: [String: Int] = [:]

        for chunk in vectorStore.allChunks() {
            if counts[chunk.documentTitle] == nil { order.append(chunk.documentTitle) }
            counts[chunk.documentTitle, default: 0] += 1
        }

        return order.map { IndexedDocument(title: $0, chunkCount: counts[$0] ?? 0) }
    }
}
