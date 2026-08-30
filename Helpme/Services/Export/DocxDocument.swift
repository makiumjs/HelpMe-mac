import SwiftUI
import UniformTypeIdentifiers

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
    static var docx: UTType {
        UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
    }
}
