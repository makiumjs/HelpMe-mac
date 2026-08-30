import Foundation

/// Scrive il markup di una mappa concettuale a partire dai nodi.
///
/// Inverso di `MindmapParser`: quello legge i rientri, questo li scrive. Il
/// contratto — trattino, due spazi per livello, ` :: ` davanti al dettaglio —
/// vive in `DidacticMarkup` e un test verifica che scrivere e rileggere
/// restituisca la stessa mappa.
public nonisolated enum MindmapComposer {

    public static func compose(_ nodes: [MindmapNode]) -> String {
        guard !nodes.isEmpty else { return "" }
        // Nessuna intestazione in cima: `MindmapParser` usa i titoli come
        // radici, quindi un "## Mappa concettuale" diventerebbe il tema
        // principale e farebbe scendere tutto di un livello.
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

/// Una riga della mappa in lavorazione.
///
/// L'albero si scrive come un elenco piatto con un livello per riga: e' il
/// modo in cui si scrive una scaletta, e non costringe a spostare rami interi
/// per cambiare idea su un nodo.
public struct MindmapDraftRow: Identifiable, Equatable {
    public let id = UUID()
    public var title: String = ""
    public var detail: String = ""
    /// 0 = tema principale. La mappa si ferma a tre livelli: oltre, su uno
    /// schermo, smette di essere leggibile a colpo d'occhio.
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

    /// Da righe piatte all'albero, saltando le righe vuote.
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

    /// Dall'albero alle righe piatte, per riaprire una mappa che c'e' gia'.
    public static func rows(from nodes: [MindmapNode], level: Int = 0) -> [MindmapDraftRow] {
        nodes.flatMap { node -> [MindmapDraftRow] in
            [MindmapDraftRow(title: node.title, detail: node.detail ?? "", level: level)]
                + rows(from: node.children, level: level + 1)
        }
    }

    /// Una riga rientrata senza un genitore sopra di se' resterebbe orfana:
    /// il rientro si concede solo se c'e' qualcosa a cui appendersi.
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
            // Un livello che salta in avanti — un dettaglio senza il suo
            // concetto sopra — si appiattisce invece di sparire.
            let level = min(item.level, stack.count)
            collapse(to: level)
            stack.append(item.node)
        }
        collapse(to: 0)
        return roots
    }
}
