import Foundation
public nonisolated struct MeasureSelection: Equatable, Sendable {
    public var selectedIds: Set<String>
    public var customCompensatory: [String]
    public var customDispensatory: [String]

    public init(
        selectedIds: Set<String> = [],
        customCompensatory: [String] = [],
        customDispensatory: [String] = []
    ) {
        self.selectedIds = selectedIds
        self.customCompensatory = customCompensatory
        self.customDispensatory = customDispensatory
    }
    public static func read(compensatory: [String], dispensatory: [String]) -> MeasureSelection {
        var selection = MeasureSelection()

        for raw in compensatory {
            if let known = MeasureCatalog.matching(raw) {
                selection.selectedIds.insert(known.id)
            } else {
                selection.customCompensatory.append(raw)
            }
        }
        for raw in dispensatory {
            if let known = MeasureCatalog.matching(raw) {
                selection.selectedIds.insert(known.id)
            } else {
                selection.customDispensatory.append(raw)
            }
        }
        return selection
    }
    public func lists() -> (compensatory: [String], dispensatory: [String]) {
        var comp = customCompensatory
        var disp = customDispensatory

        for measure in MeasureCatalog.all where selectedIds.contains(measure.id) {
            switch measure.category {
            case .compensative: comp.append(measure.id)
            case .dispensative, .assessment: disp.append(measure.id)
            }
        }
        return (comp, disp)
    }

    public func isSelected(_ measure: DidacticMeasure) -> Bool { selectedIds.contains(measure.id) }

    public mutating func toggle(_ measure: DidacticMeasure) {
        if selectedIds.contains(measure.id) {
            selectedIds.remove(measure.id)
        } else {
            selectedIds.insert(measure.id)
        }
    }

    public var customMeasures: [String] { customCompensatory + customDispensatory }

    public mutating func removeCustom(_ text: String) {
        customCompensatory.removeAll { $0 == text }
        customDispensatory.removeAll { $0 == text }
    }
}
