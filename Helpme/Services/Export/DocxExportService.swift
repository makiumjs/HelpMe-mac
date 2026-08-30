import Foundation

public final class DocxExportService: Sendable {
    public init() {}
    public func createDocxBundle(
        schoolInfo: SchoolInfo,
        student: StudentProfile,
        format: DidacticFormat,
        title: String,
        content: String,
        destinationUrl: URL,
        answerKey: String? = nil
    ) throws {
        let data = makeDocxData(
            schoolInfo: schoolInfo,
            student: student,
            format: format,
            title: title,
            content: content,
            answerKey: answerKey
        )
        do {
            try data.write(to: destinationUrl, options: .atomic)
        } catch {
            throw NSError(
                domain: "DocxExportError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Impossibile salvare il documento in \(destinationUrl.lastPathComponent): \(error.localizedDescription)"]
            )
        }
    }
    public func makeDocxData(
        schoolInfo: SchoolInfo,
        student: StudentProfile,
        format: DidacticFormat,
        title: String,
        content: String,
        answerKey: String? = nil
    ) -> Data {
        var archive = ZipArchiveWriter()
        archive.addFile(path: "[Content_Types].xml", text: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """)
        archive.addFile(path: "_rels/.rels", text: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """)
        archive.addFile(path: "word/_rels/document.xml.rels", text: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        </Relationships>
        """)
        archive.addFile(path: "word/document.xml", text: generateDocumentXml(
            school: schoolInfo,
            student: student,
            format: format,
            title: title,
            content: content,
            answerKey: answerKey
        ))

        return archive.makeArchive()
    }
    
    private func generateDocumentXml(
        school: SchoolInfo,
        student: StudentProfile,
        format: DidacticFormat,
        title: String,
        content: String,
        answerKey: String?
    ) -> String {
        let escapedSchoolName = escapeXml(school.instituteName)
        let escapedSubTypes = escapeXml(school.subTypes)
        let escapedAddress = escapeXml(school.address)
        let escapedMechCode = escapeXml(school.mechanographicCode)
        let escapedStudentName = escapeXml(student.name)
        let escapedClassInfo = escapeXml(student.classInfo)
        let escapedTeacher = escapeXml(school.teacherName)
        let escapedProgramTitle = escapeXml(student.programType.localizedTitle)
        let escapedLegalRef = escapeXml(student.programType.legalReference)
        let escapedTitle = escapeXml(title)
        
        let paragraphsXml = MarkdownToOoxml.body(from: content)
        let answerKeyXml: String
        if let answerKey, !answerKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            answerKeyXml = #"<w:p><w:r><w:br w:type="page"/></w:r></w:p>"# + MarkdownToOoxml.body(from: answerKey)
        } else {
            answerKeyXml = ""
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <!-- INTESTAZIONE ISTITUZIONALE DELLA SCUOLA -->
                <w:p>
                    <w:pPr>
                        <w:jc w:val="center"/>
                        <w:spacing w:after="40"/>
                    </w:pPr>
                    <w:r>
                        <w:rPr>
                            <w:b/>
                            <w:color w:val="1E4620"/>
                            <w:sz w:val="26"/>
                        </w:rPr>
                        <w:t xml:space="preserve">\(escapedSchoolName)</w:t>
                    </w:r>
                </w:p>
                <w:p>
                    <w:pPr>
                        <w:jc w:val="center"/>
                        <w:spacing w:after="40"/>
                    </w:pPr>
                    <w:r>
                        <w:rPr>
                            <w:i/>
                            <w:color w:val="555555"/>
                            <w:sz w:val="18"/>
                        </w:rPr>
                        <w:t xml:space="preserve">\(escapedSubTypes)</w:t>
                    </w:r>
                </w:p>
                <w:p>
                    <w:pPr>
                        <w:jc w:val="center"/>
                        <w:spacing w:after="160"/>
                        <w:pBdr>
                            <w:bottom w:val="single" w:sz="12" w:space="4" w:color="1E4620"/>
                        </w:pBdr>
                    </w:pPr>
                    <w:r>
                        <w:rPr>
                            <w:color w:val="777777"/>
                            <w:sz w:val="16"/>
                        </w:rPr>
                        <w:t xml:space="preserve">\(escapedAddress) | Cod. Mecc: \(escapedMechCode)</w:t>
                    </w:r>
                </w:p>
                
                <!-- METADATI ALUNNO E NORMATIVA D.I. 182/2020 -->
                <w:p>
                    <w:pPr>
                        <w:spacing w:before="120" w:after="60"/>
                    </w:pPr>
                    <w:r>
                        <w:rPr><w:b/><w:sz w:val="22"/></w:rPr>
                        <w:t xml:space="preserve">Alunno: </w:t>
                    </w:r>
                    <w:r>
                        <w:rPr><w:sz w:val="22"/></w:rPr>
                        <w:t xml:space="preserve">\(escapedStudentName) — Classe: \(escapedClassInfo)</w:t>
                    </w:r>
                </w:p>
                <w:p>
                    <w:pPr>
                        <w:spacing w:after="60"/>
                    </w:pPr>
                    <w:r>
                        <w:rPr><w:b/><w:sz w:val="22"/></w:rPr>
                        <w:t xml:space="preserve">Tipologia PEI: </w:t>
                    </w:r>
                    <w:r>
                        <w:rPr><w:color w:val="1E4620"/><w:b/><w:sz w:val="22"/></w:rPr>
                        <w:t xml:space="preserve">\(escapedProgramTitle) (\(escapedLegalRef))</w:t>
                    </w:r>
                </w:p>
                <w:p>
                    <w:pPr>
                        <w:spacing w:after="180"/>
                        <w:pBdr>
                            <w:bottom w:val="dotted" w:sz="6" w:space="4" w:color="CCCCCC"/>
                        </w:pBdr>
                    </w:pPr>
                    <w:r>
                        <w:rPr><w:i/><w:sz w:val="20"/><w:color w:val="555555"/></w:rPr>
                        <w:t xml:space="preserve">Docente Referente: \(escapedTeacher) — \(escapeXml(school.schoolYear))</w:t>
                    </w:r>
                </w:p>
                
                <!-- TITOLO DEL DOCUMENTO -->
                <w:p>
                    <w:pPr>
                        <w:jc w:val="center"/>
                        <w:spacing w:before="160" w:after="200"/>
                    </w:pPr>
                    <w:r>
                        <w:rPr>
                            <w:b/>
                            <w:sz w:val="30"/>
                            <w:color w:val="1E4620"/>
                        </w:rPr>
                        <w:t xml:space="preserve">\(escapedTitle)</w:t>
                    </w:r>
                </w:p>
                
                <!-- CONTENUTO DEL DOCUMENTO -->
                \(paragraphsXml)

                <!-- CHIAVE DI CORREZIONE (pagina a sé, solo se c'è un quiz) -->
                \(answerKeyXml)
                
                <!-- FIRME FINALI -->
                <w:p>
                    <w:pPr>
                        <w:spacing w:before="400" w:after="200"/>
                    </w:pPr>
                    <w:r>
                        <w:rPr><w:sz w:val="20"/></w:rPr>
                        <w:t xml:space="preserve">Il Docente Curricolare: _______________________      Il Docente di Sostegno: _______________________</w:t>
                    </w:r>
                </w:p>
                <w:sectPr>
                    <w:pgSz w:w="11906" w:h="16838"/>
                    <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/>
                </w:sectPr>
            </w:body>
        </w:document>
        """
    }
    
    private func escapeXml(_ string: String) -> String {
        MarkdownToOoxml.escape(string)
    }
}
