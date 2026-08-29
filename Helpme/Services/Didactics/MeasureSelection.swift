import Foundation

/// Le misure di un alunno, nella forma che serve a una checklist.
///
/// Tiene separate le misure riconosciute dal catalogo — che si spuntano — da
/// quelle scritte a mano in schede compilate prima che il catalogo
/// esistesse. Queste ultime **non si perdono e non si riscrivono**: se un
/// docente ha annotato "Banco vicino alla cattedra", quella misura vale, e
/// il fatto che il software non la conosca non è un problema suo.
public nonisolated struct MeasureSelection: Equatable, Sendable {
    public var selectedIds: Set<String>
    /// Diciture libere, con la lista in cui erano state salvate.
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

    /// Legge le misure salvate nella scheda.
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

    /// Riscrive le due liste da salvare nella scheda.
    ///
    /// Ogni misura conosciuta finisce nella lista che la normativa le
    /// assegna, non in quella da cui proveniva: è la stessa regola con cui
    /// la scheda PDP le impagina, applicata anche a ciò che si salva.
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
