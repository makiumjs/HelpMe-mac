import Foundation
import PDFKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public nonisolated final class DocumentIndexer: Sendable {

    public init() {}
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
    private func readPlainText(_ url: URL) throws -> String {
        var detected = String.Encoding.utf8
        if let text = try? String(contentsOf: url, usedEncoding: &detected), !text.isEmpty {
            return text
        }

        let data = try Data(contentsOf: url)
        for encoding: String.Encoding in [.utf8, .isoLatin1, .windowsCP1252] {
            if let text = String(data: data, encoding: encoding), !text.isEmpty {
                return text
            }
        }

        throw NSError(domain: "DocumentIndexer", code: 422, userInfo: [
            NSLocalizedDescriptionKey: "Impossibile riconoscere la codifica di \(url.lastPathComponent)."
        ])
    }
}
