import Foundation
import PDFKit
import NaturalLanguage

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public nonisolated final class DocumentIndexer: Sendable {

    public init() {}

    /// I formati che l'estrattore sa davvero aprire. Il selettore di file
    /// e il messaggio d'errore leggono da qui, così non possono divergere.
    public static let supportedExtensions: [String] = [
        "pdf", "docx", "epub", "txt", "md", "markdown", "rtf"
    ]

    // MARK: - Estrazione del testo

    public func extractText(from url: URL) throws -> String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "pdf":
            return try extractFromPdf(url)

        case "docx":
            return try extractFromDocx(url)

        case "epub":
            return try extractFromEpub(url)

        case "rtf":
            return try extractFromRtf(url)

        case "txt", "md", "markdown":
            return try readPlainText(url)

        default:
            let known = DocumentIndexer.supportedExtensions.map { ".\($0)" }.joined(separator: ", ")
            throw NSError(domain: "DocumentIndexer", code: 415, userInfo: [
                NSLocalizedDescriptionKey: "Formato \(ext.isEmpty ? "sconosciuto" : ".\(ext)") non supportato. Formati leggibili: \(known)."
            ])
        }
    }

    // MARK: - PDF

    private func extractFromPdf(_ url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw NSError(domain: "DocumentIndexer", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Impossibile aprire il PDF \(url.lastPathComponent). Potrebbe essere protetto da password."
            ])
        }
        var fullText = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i), let pageText = page.string {
                fullText += "\n[Pagina \(i + 1)]\n" + pageText
            }
        }
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "DocumentIndexer", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "Il PDF \(url.lastPathComponent) non contiene testo selezionabile: è probabilmente una scansione e richiede prima un riconoscimento OCR."
            ])
        }
        return fullText
    }

    // MARK: - Word

    /// Un `.docx` è un archivio OPC: il testo sta in `word/document.xml`.
    private func extractFromDocx(_ url: URL) throws -> String {
        let archive: ZipArchiveReader
        do {
            archive = try ZipArchiveReader(contentsOf: url)
        } catch {
            throw NSError(domain: "DocumentIndexer", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Impossibile aprire \(url.lastPathComponent) come documento Word: \(error.localizedDescription)"
            ])
        }

        guard archive.contains("word/document.xml") else {
            throw NSError(domain: "DocumentIndexer", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "\(url.lastPathComponent) non è un documento Word moderno. Se è un vecchio .doc, riaprilo in Word e salvalo come .docx."
            ])
        }

        let xml = try archive.text(for: "word/document.xml")
        let text = MarkupTextExtractor.textFromWordDocument(xml)

        guard !text.isEmpty else {
            throw NSError(domain: "DocumentIndexer", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "Il documento \(url.lastPathComponent) non contiene testo: forse ha solo immagini."
            ])
        }
        return text
    }

    // MARK: - EPUB

    private func extractFromEpub(_ url: URL) throws -> String {
        let archive: ZipArchiveReader
        do {
            archive = try ZipArchiveReader(contentsOf: url)
        } catch {
            throw NSError(domain: "DocumentIndexer", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Impossibile aprire \(url.lastPathComponent) come EPUB: \(error.localizedDescription)"
            ])
        }

        let text = try MarkupTextExtractor.textFromEpub(archive)
        guard !text.isEmpty else {
            throw NSError(domain: "DocumentIndexer", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "L'EPUB \(url.lastPathComponent) non contiene testo leggibile. Se è protetto da DRM non può essere aperto."
            ])
        }
        return text
    }

    // MARK: - RTF e testo semplice

    /// L'RTF va srotolato, non letto come testo: altrimenti nell'indice
    /// finirebbero i comandi di formattazione (`\rtf1`, `\fonttbl`…) invece
    /// delle parole del documento.
    private func extractFromRtf(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            throw NSError(domain: "DocumentIndexer", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "Impossibile leggere \(url.lastPathComponent): il file RTF sembra danneggiato."
            ])
        }
        return attributed.string
    }

    /// Prova UTF-8 e poi le codifiche che si incontrano davvero nei file
    /// scolastici vecchi, invece di fallire su un accento.
    private func readPlainText(_ url: URL) throws -> String {
        // Prima il rilevamento di sistema: legge il BOM e gli attributi
        // estesi del file, che sono l'indizio più affidabile.
        var detected = String.Encoding.utf8
        if let text = try? String(contentsOf: url, usedEncoding: &detected), !text.isEmpty {
            return text
        }

        let data = try Data(contentsOf: url)

        // `.utf16` è escluso di proposito: accetta quasi ogni sequenza di
        // byte di lunghezza pari, e un file Latin-1 verrebbe "letto" come
        // ideogrammi invece di passare al tentativo successivo.
        for encoding: String.Encoding in [.utf8, .isoLatin1, .windowsCP1252] {
            if let text = String(data: data, encoding: encoding), !text.isEmpty {
                return text
            }
        }

        throw NSError(domain: "DocumentIndexer", code: 422, userInfo: [
            NSLocalizedDescriptionKey: "Impossibile riconoscere la codifica di \(url.lastPathComponent)."
        ])
    }

    // MARK: - Suddivisione in frammenti

    /// Suddivide il testo in frammenti da `chunkSize` caratteri con `overlap`,
    /// tagliando dove possibile a fine frase per non spezzare i concetti.
    public func chunkText(text: String, title: String, chunkSize: Int = 500, overlap: Int = 80) -> [DocumentChunk] {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return [] }

        var chunks: [DocumentChunk] = []
        var startIndex = cleanText.startIndex

        while startIndex < cleanText.endIndex {
            let hardEnd = cleanText.index(startIndex, offsetBy: chunkSize, limitedBy: cleanText.endIndex) ?? cleanText.endIndex
            let endIndex = Self.sentenceAwareEnd(in: cleanText, from: startIndex, upTo: hardEnd)

            let chunkString = String(cleanText[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunkString.isEmpty {
                chunks.append(DocumentChunk(
                    documentTitle: title,
                    text: chunkString,
                    embedding: DocumentIndexer.embedding(for: chunkString)
                ))
            }

            if endIndex >= cleanText.endIndex { break }

            let step = max(1, cleanText.distance(from: startIndex, to: endIndex) - overlap)
            startIndex = cleanText.index(startIndex, offsetBy: step, limitedBy: cleanText.endIndex) ?? cleanText.endIndex
        }

        return chunks
    }

    /// Arretra fino all'ultimo confine di frase, se cade nell'ultimo quarto
    /// del frammento; altrimenti taglia dove capita.
    private static func sentenceAwareEnd(in text: String, from start: String.Index, upTo hardEnd: String.Index) -> String.Index {
        guard hardEnd < text.endIndex else { return hardEnd }

        let span = text.distance(from: start, to: hardEnd)
        let minimumAcceptable = text.index(start, offsetBy: (span * 3) / 4, limitedBy: text.endIndex) ?? start

        let terminators: Set<Character> = [".", "!", "?", "\n"]
        var cursor = hardEnd
        while cursor > minimumAcceptable {
            let previous = text.index(before: cursor)
            if terminators.contains(text[previous]) { return cursor }
            cursor = previous
        }
        return hardEnd
    }

    // MARK: - Vettorizzazione

    /// Modello di embedding italiano fornito dal sistema. È deterministico
    /// tra un avvio e l'altro e coglie la vicinanza di significato, non solo
    /// la coincidenza delle parole.
    private static let italianEmbedding: NLEmbedding? = {
        NLEmbedding.wordEmbedding(for: .italian) ?? NLEmbedding.wordEmbedding(for: .english)
    }()

    public static var embeddingDimension: Int {
        italianEmbedding?.dimension ?? fallbackDimension
    }

    private static let fallbackDimension = 128

    /// Vettore del testo: media dei vettori delle parole riconosciute,
    /// normalizzata. Se il modello di sistema non è disponibile si ripiega
    /// su un profilo lessicale stabile (vedi `deterministicFallback`).
    public static func embedding(for text: String) -> [Float] {
        let words = tokenize(text)
        guard !words.isEmpty else { return [] }

        guard let model = italianEmbedding else {
            return deterministicFallback(words: words)
        }

        let dimension = model.dimension
        var accumulator = [Double](repeating: 0, count: dimension)
        var matches = 0

        for word in words {
            guard let vector = model.vector(for: word) else { continue }
            for i in 0..<dimension { accumulator[i] += vector[i] }
            matches += 1
        }

        // Nessuna parola nel vocabolario (sigle, formule): meglio il profilo
        // lessicale che un vettore nullo, altrimenti il frammento è irrecuperabile.
        guard matches > 0 else { return deterministicFallback(words: words) }

        var result = accumulator.map { Float($0 / Double(matches)) }
        normalize(&result)
        return result
    }

    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
    }

    /// Profilo lessicale con hash **stabile tra le esecuzioni**: `hashValue`
    /// di String è randomizzato a ogni avvio del processo e renderebbe
    /// inservibile qualunque indice salvato su disco.
    static func deterministicFallback(words: [String], dimension: Int = fallbackDimension) -> [Float] {
        var vector = [Float](repeating: 0, count: dimension)
        for word in words {
            let index = Int(stableHash(word) % UInt64(dimension))
            vector[index] += Float(word.count)
        }
        normalize(&vector)
        return vector
    }

    /// FNV-1a: stessa stringa, stesso valore, per sempre.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    private static func normalize(_ vector: inout [Float]) {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return }
        for i in vector.indices { vector[i] /= norm }
    }
}
