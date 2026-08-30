import Foundation
public nonisolated enum MindmapComposer {

    public static func compose(_ nodes: [MindmapNode]) -> String {
        guard !nodes.isEmpty else { return "" }
        var lines: [String] = []
        appendNodes(nodes, level: 0, into: &lines)
        return lines.joined(separator: "\n")
    }

    private static func appendNodes(_ nodes: [MindmapNode], level: Int, into lines: inout [String]) {
        for node in nodes {
            let indent = String(repeating: "  ", count: level)
            var line = "\(indent)- \(node.title)"
            if let detail = node.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
                line += " :: \(detail)"
            }
            lines.append(line)
            appendNodes(node.children, level: level + 1, into: &lines)
        }
    }
}
public nonisolated struct MindmapDraftRow: Identifiable, Equatable {
    public let id = UUID()
    public var title: String = ""
    public var detail: String = ""
    public var level: Int = 0

    public init(title: String = "", detail: String = "", level: Int = 0) {
        self.title = title
        self.detail = detail
        self.level = level
    }

    public var isFilled: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
}

public nonisolated enum MindmapDraft {

    public static let maximumLevel = 2
    public static func nodes(from rows: [MindmapDraftRow]) -> [MindmapNode] {
        var levelled: [(level: Int, node: MindmapNode)] = []
        for row in rows where row.isFilled {
            let detail = row.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            levelled.append((
                min(row.level, maximumLevel),
                MindmapNode(title: row.title.trimmingCharacters(in: .whitespaces),
                            detail: detail.isEmpty ? nil : detail)
            ))
        }
        return assemble(levelled)
    }
    public static func rows(from nodes: [MindmapNode], level: Int = 0) -> [MindmapDraftRow] {
        nodes.flatMap { node -> [MindmapDraftRow] in
            [MindmapDraftRow(title: node.title, detail: node.detail ?? "", level: level)]
                + rows(from: node.children, level: level + 1)
        }
    }

    public static func canIndent(_ rows: [MindmapDraftRow], at index: Int) -> Bool {
        guard rows.indices.contains(index), index > 0 else { return false }
        guard rows[index].level < maximumLevel else { return false }
        return rows[index].level <= rows[index - 1].level
    }

    private static func assemble(_ items: [(level: Int, node: MindmapNode)]) -> [MindmapNode] {
        var roots: [MindmapNode] = []
        var stack: [MindmapNode] = []

        func collapse(to depth: Int) {
            while stack.count > depth {
                let finished = stack.removeLast()
                if stack.isEmpty { roots.append(finished) } else { stack[stack.count - 1].children.append(finished) }
            }
        }

        for item in items {
            let level = min(item.level, stack.count)
            collapse(to: level)
            stack.append(item.node)
        }
        collapse(to: 0)
        return roots
    }
}
