import Foundation
public nonisolated struct MindmapNode: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public var title: String
    public var detail: String?
    public var children: [MindmapNode]

    public init(title: String, detail: String? = nil, children: [MindmapNode] = []) {
        self.title = title
        self.detail = detail
        self.children = children
    }
    public var totalCount: Int {
        1 + children.reduce(0) { $0 + $1.totalCount }
    }

    public var depth: Int {
        1 + (children.map(\.depth).max() ?? 0)
    }
}
public nonisolated enum MindmapParser {
    private struct RawItem {
        let indent: Int
        let text: String
        let headingLevel: Int?
    }

    public static func parse(_ markdown: String) -> [MindmapNode] {
        let items = rawItems(from: markdown)
        guard !items.isEmpty else { return [] }

        let bulletIndents = Set(items.filter { $0.headingLevel == nil }.map(\.indent)).sorted()
        var indentRank: [Int: Int] = [:]
        for (rank, indent) in bulletIndents.enumerated() { indentRank[indent] = rank }
        var levelled: [(level: Int, node: MindmapNode)] = []
        var headingBase = -1

        for item in items {
            let level: Int
            if let headingLevel = item.headingLevel {
                level = max(0, headingLevel - 1)
                headingBase = level
            } else {
                level = headingBase + 1 + (indentRank[item.indent] ?? 0)
            }

            let (title, detail) = splitTitleAndDetail(item.text)
            guard !title.isEmpty else { continue }
            levelled.append((level, MindmapNode(title: title, detail: detail)))
        }

        return assemble(levelled)
    }

    // MARK: - Righe grezze

    private static func rawItems(from markdown: String) -> [RawItem] {
        var items: [RawItem] = []

        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }), trimmed.count >= 3 { continue }

            if let hashes = headingLevel(of: trimmed) {
                let text = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { items.append(RawItem(indent: 0, text: text, headingLevel: hashes)) }
                continue
            }

            guard let content = bulletContent(of: trimmed) else { continue }
            items.append(RawItem(indent: indentWidth(of: line), text: content, headingLevel: nil))
        }

        return items
    }

    private static func headingLevel(of line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let count = line.prefix { $0 == "#" }.count
        return (1...6).contains(count) ? count : nil
    }
    private static func bulletContent(of line: String) -> String? {
        if DidacticMarkup.isQuizOption(line) { return nil }

        for marker in ["- ", "* ", "+ ", "• ", "◦ ", "‣ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty {
            let rest = line.dropFirst(digits.count)
            if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
                return String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }

        return nil
    }
    private static func indentWidth(of line: String) -> Int {
        var width = 0
        for character in line {
            if character == " " { width += 1 }
            else if character == "\t" { width += 2 }
            else { break }
        }
        return width
    }
    static func splitTitleAndDetail(_ text: String) -> (title: String, detail: String?) {
        let cleaned = stripEmphasis(text)

        for separator in [" :: ", "::", " — ", " – "] {
            if let range = cleaned.range(of: separator) {
                let title = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let detail = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && !detail.isEmpty { return (title, detail) }
            }
        }
        if let colon = cleaned.firstIndex(of: ":") {
            let title = String(cleaned[..<colon]).trimmingCharacters(in: .whitespaces)
            let detail = String(cleaned[cleaned.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty, !detail.isEmpty, title.count <= 60 {
                return (title, detail)
            }
        }

        return (cleaned, nil)
    }

    static func stripEmphasis(_ text: String) -> String {
        var output = text
        for marker in ["***", "**", "__", "*", "_", "`"] {
            output = output.replacingOccurrences(of: marker, with: "")
        }
        return output.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Costruzione dell'albero
    private static func assemble(_ items: [(level: Int, node: MindmapNode)]) -> [MindmapNode] {
        var roots: [MindmapNode] = []
        var stack: [MindmapNode] = []

        func collapse(to depth: Int) {
            while stack.count > depth {
                let finished = stack.removeLast()
                if stack.isEmpty {
                    roots.append(finished)
                } else {
                    stack[stack.count - 1].children.append(finished)
                }
            }
        }

        for item in items {
            let targetDepth = min(item.level, stack.count)
            collapse(to: targetDepth)
            stack.append(item.node)
        }
        collapse(to: 0)

        return roots
    }
}
