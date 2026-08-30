import Foundation
nonisolated enum MarkdownToOoxml {

    private static let accentGreen = "1E4620"
    private static let midGreen = "2E7D32"

    // MARK: - Ingresso

    static func body(from content: String) -> String {
        var xml = ""
        let lines = content.components(separatedBy: .newlines)
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if isTableRow(line), index + 1 < lines.count,
               isTableSeparator(lines[index + 1].trimmingCharacters(in: .whitespaces)) {
                var tableLines: [String] = [line]
                var cursor = index + 2
                while cursor < lines.count {
                    let candidate = lines[cursor].trimmingCharacters(in: .whitespaces)
                    guard isTableRow(candidate) else { break }
                    tableLines.append(candidate)
                    cursor += 1
                }
                xml += table(from: tableLines)
                xml += emptyParagraph()
                index = cursor
                continue
            }

            xml += paragraph(from: line)
            index += 1
        }

        return xml
    }

    // MARK: - Paragrafi

    private static func paragraph(from line: String) -> String {
        if line.isEmpty { return emptyParagraph() }

        if line.hasPrefix("# ") {
            return heading(text: String(line.dropFirst(2)), size: 32, color: accentGreen, before: 240, after: 120)
        }
        if line.hasPrefix("## ") || line.hasPrefix("### ") {
            let stripped = line.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
            return heading(text: stripped, size: 26, color: midGreen, before: 180, after: 80)
        }
        if line.range(of: "^([-*_])\\1{2,}$", options: .regularExpression) != nil {
            return """
            <w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="CCCCCC"/></w:pBdr></w:pPr></w:p>
            """
        }
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return bullet(text: String(line.dropFirst(2)))
        }
        if let match = line.range(of: "^\\d+[.)]\\s+", options: .regularExpression) {
            let marker = String(line[match]).trimmingCharacters(in: .whitespaces)
            return numbered(marker: marker, text: String(line[match.upperBound...]))
        }

        return """
        <w:p>
            <w:pPr><w:spacing w:after="100"/></w:pPr>
            \(runs(from: line, size: 22))
        </w:p>
        """
    }

    private static func emptyParagraph() -> String {
        "<w:p><w:r><w:t xml:space=\"preserve\"></w:t></w:r></w:p>\n"
    }

    private static func heading(text: String, size: Int, color: String, before: Int, after: Int) -> String {
        """
        <w:p>
            <w:pPr><w:spacing w:before="\(before)" w:after="\(after)"/><w:keepNext/></w:pPr>
            \(runs(from: text, size: size, bold: true, color: color))
        </w:p>
        """
    }

    private static func bullet(text: String) -> String {
        """
        <w:p>
            <w:pPr><w:ind w:left="720" w:hanging="240"/><w:spacing w:after="60"/></w:pPr>
            <w:r><w:rPr><w:color w:val="\(midGreen)"/><w:b/><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">•\u{00A0}</w:t></w:r>
            \(runs(from: text, size: 22))
        </w:p>
        """
    }

    private static func numbered(marker: String, text: String) -> String {
        """
        <w:p>
            <w:pPr><w:ind w:left="720" w:hanging="360"/><w:spacing w:after="60"/></w:pPr>
            <w:r><w:rPr><w:color w:val="\(midGreen)"/><w:b/><w:sz w:val="22"/></w:rPr><w:t xml:space="preserve">\(escape(marker))\u{00A0}</w:t></w:r>
            \(runs(from: text, size: 22))
        </w:p>
        """
    }

    // MARK: - Tabelle

    private static func isTableRow(_ line: String) -> Bool {
        line.hasPrefix("|") && line.dropFirst().contains("|")
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        guard isTableRow(line) else { return false }
        let cells = splitCells(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let stripped = cell.replacingOccurrences(of: " ", with: "")
            return !stripped.isEmpty && stripped.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func splitCells(_ line: String) -> [String] {
        var trimmed = line
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func table(from lines: [String]) -> String {
        let rows = lines.map(splitCells)
        guard let header = rows.first else { return "" }
        let columnCount = rows.map(\.count).max() ?? header.count

        var xml = """
        <w:tbl>
            <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                    <w:top w:val="single" w:sz="6" w:space="0" w:color="\(midGreen)"/>
                    <w:left w:val="single" w:sz="6" w:space="0" w:color="\(midGreen)"/>
                    <w:bottom w:val="single" w:sz="6" w:space="0" w:color="\(midGreen)"/>
                    <w:right w:val="single" w:sz="6" w:space="0" w:color="\(midGreen)"/>
                    <w:insideH w:val="single" w:sz="4" w:space="0" w:color="AAAAAA"/>
                    <w:insideV w:val="single" w:sz="4" w:space="0" w:color="AAAAAA"/>
                </w:tblBorders>
                <w:tblCellMar>
                    <w:top w:w="60" w:type="dxa"/><w:left w:w="100" w:type="dxa"/>
                    <w:bottom w:w="60" w:type="dxa"/><w:right w:w="100" w:type="dxa"/>
                </w:tblCellMar>
            </w:tblPr>
        """

        for (rowIndex, row) in rows.enumerated() {
            let isHeader = rowIndex == 0
            xml += "<w:tr>"
            if isHeader { xml += "<w:trPr><w:tblHeader/></w:trPr>" }

            for column in 0..<columnCount {
                let cell = column < row.count ? row[column] : ""
                let shading = isHeader ? "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"E8F0E8\"/>" : ""
                xml += """
                <w:tc>
                    <w:tcPr><w:tcW w:w="0" w:type="auto"/>\(shading)<w:vAlign w:val="center"/></w:tcPr>
                    <w:p>
                        <w:pPr><w:spacing w:before="20" w:after="20"/></w:pPr>
                        \(runs(from: cell, size: 20, bold: isHeader))
                    </w:p>
                </w:tc>
                """
            }
            xml += "</w:tr>"
        }

        xml += "</w:tbl>"
        return xml
    }

    // MARK: - Testo con grassetto e corsivo
    static func runs(from text: String, size: Int, bold: Bool = false, color: String? = nil) -> String {
        let segments = parseInline(text)
        guard !segments.isEmpty else {
            return "<w:r><w:rPr><w:sz w:val=\"\(size)\"/></w:rPr><w:t xml:space=\"preserve\"></w:t></w:r>"
        }

        return segments.map { segment in
            var properties = "<w:sz w:val=\"\(size)\"/>"
            if bold || segment.bold { properties += "<w:b/>" }
            if segment.italic { properties += "<w:i/>" }
            if segment.code { properties += "<w:rFonts w:ascii=\"Menlo\" w:hAnsi=\"Menlo\"/>" }
            if let color { properties += "<w:color w:val=\"\(color)\"/>" }
            return "<w:r><w:rPr>\(properties)</w:rPr><w:t xml:space=\"preserve\">\(escape(segment.text))</w:t></w:r>"
        }.joined()
    }

    struct Segment: Equatable {
        var text: String
        var bold = false
        var italic = false
        var code = false
    }

    static func parseInline(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var buffer = ""
        var bold = false
        var italic = false
        var code = false

        func flush() {
            guard !buffer.isEmpty else { return }
            segments.append(Segment(text: buffer, bold: bold, italic: italic, code: code))
            buffer = ""
        }

        let characters = Array(text)
        var i = 0
        while i < characters.count {
            let char = characters[i]
            let next = i + 1 < characters.count ? characters[i + 1] : nil

            if !code, char == "*", next == "*" {
                flush(); bold.toggle(); i += 2; continue
            }
            if !code, char == "*" || char == "_" {
                let previous = i > 0 ? characters[i - 1] : nil
                let insideWord = char == "_" && (previous?.isLetter == true) && (next?.isLetter == true)
                if !insideWord {
                    flush(); italic.toggle(); i += 1; continue
                }
            }
            if char == "`" {
                flush(); code.toggle(); i += 1; continue
            }

            buffer.append(char)
            i += 1
        }

        flush()
        return segments
    }

    // MARK: - Escape

    static func escape(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for scalar in string.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default:
                let value = scalar.value
                let allowed = value == 0x09 || value == 0x0A || value == 0x0D || value >= 0x20
                if allowed { result.unicodeScalars.append(scalar) }
            }
        }
        return result
    }
}
