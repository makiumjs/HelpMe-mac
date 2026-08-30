import SwiftUI
public struct MindmapCardView: View {
    @Bindable public var viewModel: StudentReaderViewModel
    public let settings: AccessibilitySettings
    public var onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(
        viewModel: StudentReaderViewModel,
        settings: AccessibilitySettings,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.settings = settings
        self.onClose = onClose
    }
    private var nodes: [MindmapNode] { viewModel.mindmapNodes }
    private var collapsed: Set<UUID> { viewModel.collapsedMindmapNodes }
    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if nodes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(visibleRows) { row in
                            branch(row)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .themedSurface(settings)
        .frame(minWidth: 460, idealWidth: 620, minHeight: 380, idealHeight: 560)
    }
    // MARK: - Intestazione
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(settings.theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Mappa concettuale")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(settings.theme.text)
                Text(summaryLine)
                    .font(.system(size: 11))
                    .foregroundStyle(settings.theme.text.opacity(0.65))
            }
            Spacer()
            if !nodes.isEmpty {
                Button(allCollapsed ? "Apri tutto" : "Chiudi tutto") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        allCollapsed ? viewModel.collapsedMindmapNodes.removeAll() : collapseEverything()
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            Button("Chiudi", action: onClose)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(settings.theme.background)
    }
    private var summaryLine: String {
        let total = nodes.reduce(0) { $0 + $1.totalCount }
        let levels = nodes.map(\.depth).max() ?? 0
        return "\(Plural.it(total, "concetto", "concetti")) su \(Plural.it(levels, "livello", "livelli")) — tocca un ramo per aprirlo o chiuderlo"
    }
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 40))
                .foregroundStyle(settings.theme.text.opacity(0.4))
            Text("Non c'è ancora una mappa da mostrare.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(settings.theme.text)
            Text("Genera il materiale con il formato «Mappa Concettuale»: i punti elenco annidati diventano rami navigabili.")
                .font(.system(size: 12))
                .foregroundStyle(settings.theme.text.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Rami
    private struct Row: Identifiable {
        let id: UUID
        let node: MindmapNode
        let level: Int
        let isCollapsed: Bool
        var hasChildren: Bool { !node.children.isEmpty }
        var hiddenCount: Int { isCollapsed ? node.totalCount - 1 : 0 }
    }
    private var visibleRows: [Row] {
        var rows: [Row] = []

        func walk(_ node: MindmapNode, level: Int) {
            let isCollapsed = collapsed.contains(node.id)
            rows.append(Row(id: node.id, node: node, level: level, isCollapsed: isCollapsed))
            guard !isCollapsed else { return }
            for child in node.children { walk(child, level: level + 1) }
        }
        for node in nodes { walk(node, level: 0) }
        return rows
    }
    private func branch(_ row: Row) -> some View {
        let level = row.level
        let node = row.node
        return Button {
            guard row.hasChildren else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                if row.isCollapsed {
                    viewModel.collapsedMindmapNodes.remove(node.id)
                } else {
                    viewModel.collapsedMindmapNodes.insert(node.id)
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: row.hasChildren ? (row.isCollapsed ? "chevron.right" : "chevron.down") : "circle.fill")
                    .font(.system(size: row.hasChildren ? 11 : 5, weight: .bold))
                    .foregroundStyle(tint(for: level))
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(settings.fontFamily.font(
                            size: titleSize(for: level),
                            weight: level == 0 ? .bold : .semibold
                        ))
                        .tracking(CGFloat(settings.letterSpacing))
                        .foregroundStyle(settings.theme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = node.detail {
                        Text(detail)
                            .font(settings.fontFamily.font(size: max(12, titleSize(for: level) - 3)))
                            .tracking(CGFloat(settings.letterSpacing))
                            .foregroundStyle(settings.theme.text.opacity(0.75))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if row.hiddenCount > 0 {
                        Text(row.hiddenCount == 1
                             ? "1 sotto-concetto nascosto"
                             : "\(row.hiddenCount) sotto-concetti nascosti")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(tint(for: level).opacity(0.9))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(tint(for: level).opacity(fillOpacity(for: level)))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(tint(for: level).opacity(strokeOpacity(for: level)), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(row.hasChildren)
        .padding(.leading, CGFloat(level) * 22)
        .overlay(alignment: .leading) { indentGuides(upTo: level) }
        .accessibilityLabel(accessibilityLabel(for: row))
        .accessibilityHint(row.hasChildren ? (row.isCollapsed ? "Tocca per aprire il ramo" : "Tocca per chiudere il ramo") : "")
        .accessibilityAddTraits(row.hasChildren ? .isButton : [])
    }

    @ViewBuilder
    private func indentGuides(upTo level: Int) -> some View {
        if level > 0 {
            HStack(spacing: 0) {
                ForEach(0..<level, id: \.self) { depth in
                    Rectangle()
                        .fill(tint(for: depth).opacity(0.28))
                        .frame(width: 2)
                        .padding(.leading, depth == 0 ? 7 : 20)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func accessibilityLabel(for row: Row) -> String {
        var parts = ["Livello \(row.level + 1): \(row.node.title)"]
        if let detail = row.node.detail { parts.append(detail) }
        if row.hasChildren { parts.append("\(row.node.children.count) sotto-concetti") }
        return parts.joined(separator: ". ")
    }

    private func titleSize(for level: Int) -> CGFloat {
        let base = CGFloat(settings.fontSize)
        switch level {
        case 0:  return base + 2
        case 1:  return base
        default: return max(13, base - 1)
        }
    }
    private func tint(for level: Int) -> Color {
        settings.theme.accent
    }
    private func fillOpacity(for level: Int) -> Double {
        switch level {
        case 0:  return 0.16
        case 1:  return 0.09
        default: return 0.05
        }
    }
    private func strokeOpacity(for level: Int) -> Double {
        switch level {
        case 0:  return 0.45
        case 1:  return 0.28
        default: return 0.16
        }
    }
    // MARK: - Apri / chiudi tutto

    private var allCollapsed: Bool {
        !collapsed.isEmpty
    }
    private func collapseEverything() {
        var identifiers: Set<UUID> = []
        func walk(_ node: MindmapNode) {
            if !node.children.isEmpty { identifiers.insert(node.id) }
            node.children.forEach(walk)
        }
        nodes.forEach(walk)
        viewModel.collapsedMindmapNodes = identifiers
    }
}
