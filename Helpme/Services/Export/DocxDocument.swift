import SwiftUI
import UniformTypeIdentifiers

/// Involucro del .docx già confezionato, per il pannello "Salva con nome".
///
/// Passando da `fileExporter` è il docente a scegliere la cartella — anche
/// una condivisa della scuola — e la sandbox concede l'accesso a quel percorso
/// senza bisogno di entitlement su cartelle fisse.
public struct DocxDocument: FileDocument {

    public static var readableContentTypes: [UTType] { [.docx] }
    public static var writableContentTypes: [UTType] { [.docx] }

    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

public extension UTType {
    /// Tipo di Microsoft Word registrato dal sistema.
    static var docx: UTType {
        UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
    }
}
