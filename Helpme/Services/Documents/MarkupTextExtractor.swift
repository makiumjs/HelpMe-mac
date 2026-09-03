import Foundation
nonisolated enum MarkupTextExtractor {

    // MARK: - Word (word/document.xml)
    static func textFromWordDocument(_ xml: String) -> String {
        var output = ""
        var insideTextRun = false
        var cellDepth = 0

        scanMarkup(xml) { event in
            switch event {
            case .text(let value):
                if insideTextRun { output += value }

            case .tag(let name, let kind):
                switch (name, kind) {
                case ("w:t", .open):        insideTextRun = true
                case ("w:t", .close):       insideTextRun = false
                case ("w:tab", _):          output += "\t"
                case ("w:br", _):           output += "\n"
                case ("w:cr", _):           output += "\n"
                case ("w:p", .close):       output += cellDepth > 0 ? " " : "\n"
                case ("w:tc", .open):       cellDepth += 1
                case ("w:tc", .close):      cellDepth = max(0, cellDepth - 1); output += "\t"
                case ("w:tr", .close):      output += "\n"
                default:                    break
                }
            }
        }

        return tidy(output)
    }

    // MARK: - HTML / XHTML

    private static let blockTags: Set<String> = [
        "p", "div", "br", "hr", "li", "tr", "section", "article", "header",
        "footer", "blockquote", "pre", "figcaption", "dt", "dd",
        "h1", "h2", "h3", "h4", "h5", "h6"
    ]

    private static let skippedTags: Set<String> = ["script", "style", "head", "svg"]
    static func textFromHtml(_ html: String) -> String {
        var output = ""
        var suppressionDepth = 0
        var suppressingTag: String? = nil

        scanMarkup(html) { event in
            switch event {
            case .text(let value):
                if suppressionDepth == 0 { output += value }

            case .tag(let name, let kind):
                if skippedTags.contains(name) {
                    switch kind {
                    case .open:
                        if suppressionDepth == 0 { suppressingTag = name }
                        if suppressingTag == name { suppressionDepth += 1 }
                    case .close:
                        if suppressingTag == name {
                            suppressionDepth = max(0, suppressionDepth - 1)
                            if suppressionDepth == 0 { suppressingTag = nil }
                        }
                    case .selfClosing:
                        break
                    }
                    return
                }

                guard suppressionDepth == 0 else { return }

                if blockTags.contains(name) {
                    output += "\n"
                } else if kind != .close {
                    output += " "
                }
            }
        }

        return tidy(output)
    }

    // MARK: - EPUB
    static func textFromEpub(_ archive: ZipArchiveReader) throws -> String {
        let documents = epubReadingOrder(in: archive)
        guard !documents.isEmpty else {
            throw NSError(domain: "MarkupTextExtractor", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "L'EPUB non contiene capitoli leggibili."
            ])
        }

        var pieces: [String] = []
        for path in documents {
            guard let markup = try? archive.text(for: path) else { continue }
            let text = textFromHtml(markup)
            if !text.isEmpty { pieces.append(text) }
        }

        return pieces.joined(separator: "\n\n")
    }
    private static func epubReadingOrder(in archive: ZipArchiveReader) -> [String] {
        guard let containerXml = try? archive.text(for: "META-INF/container.xml"),
              let opfPath = attribute("full-path", ofFirst: "rootfile", in: containerXml),
              let opfXml = try? archive.text(for: opfPath) else {
            return fallbackDocuments(in: archive)
        }

        let basePath = (opfPath as NSString).deletingLastPathComponent
        var manifest: [String: String] = [:]
        for tag in tags(named: "item", in: opfXml) {
            guard let id = attribute("id", in: tag), let href = attribute("href", in: tag) else { continue }
            let mediaType = attribute("media-type", in: tag) ?? ""
            guard mediaType.contains("xhtml") || mediaType.contains("html") || mediaType.isEmpty else { continue }
            manifest[id] = href
        }
        var ordered: [String] = []
        for tag in tags(named: "itemref", in: opfXml) {
            guard let idref = attribute("idref", in: tag), let href = manifest[idref] else { continue }
            let resolved = resolve(href: href, relativeTo: basePath)
            if archive.contains(resolved) { ordered.append(resolved) }
        }

        return ordered.isEmpty ? fallbackDocuments(in: archive) : ordered
    }

    private static func fallbackDocuments(in archive: ZipArchiveReader) -> [String] {
        archive.paths
            .filter {
                let ext = ($0 as NSString).pathExtension.lowercased()
                return ext == "xhtml" || ext == "html" || ext == "htm"
            }
            .sorted()
    }
    private static func resolve(href: String, relativeTo base: String) -> String {
        let decoded = href.removingPercentEncoding ?? href
        let withoutFragment = decoded.components(separatedBy: "#").first ?? decoded
        guard !base.isEmpty else { return withoutFragment }

        var components: [String] = base.components(separatedBy: "/").filter { !$0.isEmpty }
        for part in withoutFragment.components(separatedBy: "/") {
            switch part {
            case "", ".":   continue
            case "..":      if !components.isEmpty { components.removeLast() }
            default:        components.append(part)
            }
        }
        return components.joined(separator: "/")
    }

    // MARK: - Micro-parser di tag
    private enum TagKind { case open, close, selfClosing }
    private enum MarkupEvent {
        case text(String)
        case tag(name: String, kind: TagKind)
    }
    private static func scanMarkup(_ markup: String, _ handle: (MarkupEvent) -> Void) {
        let scalars = Array(markup.unicodeScalars)
        var index = 0
        var textBuffer = String.UnicodeScalarView()
        func flushText() {
            guard !textBuffer.isEmpty else { return }
            handle(.text(decodeEntities(String(textBuffer))))
            textBuffer = String.UnicodeScalarView()
        }
        while index < scalars.count {
            let scalar = scalars[index]

            guard scalar == "<" else {
                textBuffer.append(scalar)
                index += 1
                continue
            }
            if matches("!--", at: index + 1, in: scalars) {
                flushText()
                index = skip(to: "-->", from: index + 4, in: scalars)
                continue
            }
            if matches("![CDATA[", at: index + 1, in: scalars) {
                let start = index + 9
                let end = indexOf("]]>", from: start, in: scalars) ?? scalars.count
                textBuffer.append(contentsOf: scalars[start..<min(end, scalars.count)])
                index = end < scalars.count ? end + 3 : scalars.count
                continue
            }

            guard let tagEnd = indexOfTagEnd(from: index + 1, in: scalars) else {
                textBuffer.append(scalar)
                index += 1
                continue
            }

            flushText()

            let body = scalars[(index + 1)..<tagEnd]
            let isClosing = body.first == "/"
            let isSelfClosing = body.last == "/"
            var nameScalars = String.UnicodeScalarView()
            for scalar in body.dropFirst(isClosing ? 1 : 0) {
                if scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" || scalar == "/" { break }
                nameScalars.append(scalar)
            }

            let name = String(nameScalars).lowercased()
            if !name.isEmpty && !name.hasPrefix("?") && !name.hasPrefix("!") {
                handle(.tag(name: name, kind: isClosing ? .close : (isSelfClosing ? .selfClosing : .open)))
            }

            index = tagEnd + 1
        }

        flushText()
    }
    private static func indexOfTagEnd(from start: Int, in scalars: [Unicode.Scalar]) -> Int? {
        var quote: Unicode.Scalar? = nil
        var index = start
        while index < scalars.count {
            let scalar = scalars[index]
            if let open = quote {
                if scalar == open { quote = nil }
            } else if scalar == "\"" || scalar == "'" {
                quote = scalar
            } else if scalar == ">" {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func matches(_ needle: String, at start: Int, in scalars: [Unicode.Scalar]) -> Bool {
        let needleScalars = Array(needle.unicodeScalars)
        guard start >= 0, start + needleScalars.count <= scalars.count else { return false }
        for offset in needleScalars.indices where scalars[start + offset] != needleScalars[offset] {
            return false
        }
        return true
    }

    private static func indexOf(_ needle: String, from start: Int, in scalars: [Unicode.Scalar]) -> Int? {
        var index = max(0, start)
        while index < scalars.count {
            if matches(needle, at: index, in: scalars) { return index }
            index += 1
        }
        return nil
    }

    private static func skip(to needle: String, from start: Int, in scalars: [Unicode.Scalar]) -> Int {
        guard let found = indexOf(needle, from: start, in: scalars) else { return scalars.count }
        return found + needle.unicodeScalars.count
    }

    // MARK: - Attributi
    static func tags(named name: String, in markup: String) -> [String] {
        var found: [String] = []
        let scalars = Array(markup.unicodeScalars)
        var index = 0

        while index < scalars.count {
            guard scalars[index] == "<",
                  let end = indexOfTagEnd(from: index + 1, in: scalars) else {
                index += 1
                continue
            }

            let body = String(String.UnicodeScalarView(scalars[(index + 1)..<end]))
            let tagName = body
                .prefix { $0 != " " && $0 != "\t" && $0 != "\n" && $0 != "\r" && $0 != "/" }
                .lowercased()

            if tagName == name.lowercased() { found.append(body) }
            index = end + 1
        }

        return found
    }
    static func attribute(_ name: String, in tagBody: String) -> String? {
        let scalars = Array(tagBody.unicodeScalars)
        let target = Array(name.lowercased().unicodeScalars)
        var index = 0

        while index < scalars.count {
            let atBoundary = index == 0 || scalars[index - 1] == " " || scalars[index - 1] == "\t"
                || scalars[index - 1] == "\n" || scalars[index - 1] == "\r"

            guard atBoundary, matchesScalars(target, at: index, in: scalars) else {
                index += 1
                continue
            }
            var cursor = index + target.count
            while cursor < scalars.count, scalars[cursor] == " " { cursor += 1 }
            guard cursor < scalars.count, scalars[cursor] == "=" else {
                index += 1
                continue
            }
            cursor += 1
            while cursor < scalars.count, scalars[cursor] == " " { cursor += 1 }
            guard cursor < scalars.count else { return nil }

            let delimiter = scalars[cursor]
            if delimiter == "\"" || delimiter == "'" {
                cursor += 1
                var value = String.UnicodeScalarView()
                while cursor < scalars.count, scalars[cursor] != delimiter {
                    value.append(scalars[cursor])
                    cursor += 1
                }
                return decodeEntities(String(value))
            }
            var value = String.UnicodeScalarView()
            while cursor < scalars.count, scalars[cursor] != " ", scalars[cursor] != ">" {
                value.append(scalars[cursor])
                cursor += 1
            }
            return decodeEntities(String(value))
        }
        return nil
    }
    static func attribute(_ name: String, ofFirst tagName: String, in markup: String) -> String? {
        for body in tags(named: tagName, in: markup) {
            if let value = attribute(name, in: body) { return value }
        }
        return nil
    }

    private static func matchesScalars(_ needle: [Unicode.Scalar], at start: Int, in scalars: [Unicode.Scalar]) -> Bool {
        guard start + needle.count <= scalars.count else { return false }
        for offset in needle.indices {
            let candidate = String(scalars[start + offset]).lowercased()
            if candidate != String(needle[offset]) { return false }
        }
        return true
    }

    // MARK: - Entità e ripulitura
    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": " ", "ndash": "–", "mdash": "—", "hellip": "…",
        "laquo": "«", "raquo": "»", "eacute": "é", "egrave": "è",
        "agrave": "à", "igrave": "ì", "ograve": "ò", "ugrave": "ù",
        "deg": "°", "euro": "€", "rsquo": "'", "lsquo": "'",
        "ldquo": "\u{201C}", "rdquo": "\u{201D}"
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }

        var output = ""
        var iterator = text.startIndex

        while iterator < text.endIndex {
            guard text[iterator] == "&",
                  let semicolon = text[iterator...].firstIndex(of: ";"),
                  text.distance(from: iterator, to: semicolon) <= 10 else {
                output.append(text[iterator])
                iterator = text.index(after: iterator)
                continue
            }

            let body = String(text[text.index(after: iterator)..<semicolon])

            if body.hasPrefix("#") {
                let digits = String(body.dropFirst())
                let value: UInt32?
                if digits.lowercased().hasPrefix("x") {
                    value = UInt32(digits.dropFirst(), radix: 16)
                } else {
                    value = UInt32(digits)
                }
                if let value, let scalar = Unicode.Scalar(value) {
                    output.append(Character(scalar))
                    iterator = text.index(after: semicolon)
                    continue
                }
            } else if let replacement = namedEntities[body.lowercased()] {
                output += replacement
                iterator = text.index(after: semicolon)
                continue
            }

            output.append(text[iterator])
            iterator = text.index(after: iterator)
        }

        return output
    }
    static func tidy(_ text: String) -> String {
        var lines: [String] = []

        for rawLine in text.components(separatedBy: "\n") {
            var cells = rawLine.components(separatedBy: "\t").map { cell in
                cell.components(separatedBy: " ")
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            while cells.last?.isEmpty == true { cells.removeLast() }

            let collapsed = cells.joined(separator: "\t")
            if collapsed.isEmpty { continue }
            lines.append(collapsed)
        }
        return lines.joined(separator: "\n")
    }
}
