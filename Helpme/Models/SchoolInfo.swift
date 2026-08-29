import Foundation
import SwiftData

/// Intestazione istituzionale usata nei documenti .docx esportati.
/// Ne esiste una sola istanza nell'archivio, recuperata da `PersistenceController`.
@Model
public final class SchoolInfo {
    public var instituteName: String
    public var subTypes: String
    public var mechanographicCode: String
    public var address: String
    public var schoolYear: String
    public var teacherName: String
    public var primaryColorHex: String

    public init(
        instituteName: String = "I.I.S. \"Antonio Della Lucia\" Feltre",
        subTypes: String = "Istituto Prof.le Agricoltura e Ambiente – Istituto Tecnico per l'Agricoltura",
        mechanographicCode: String = "BLIS009002 – BLRA009012 – BLTA00901T",
        address: String = "Via Vellai, 41 - 32032 Feltre (BL) - Tel. 0439840202",
        schoolYear: String = SchoolInfo.currentSchoolYear(),
        teacherName: String = "Docente di Sostegno Referente",
        primaryColorHex: String = "#1E4620"
    ) {
        self.instituteName = instituteName
        self.subTypes = subTypes
        self.mechanographicCode = mechanographicCode
        self.address = address
        self.schoolYear = schoolYear
        self.teacherName = teacherName
        self.primaryColorHex = primaryColorHex
    }

    /// L'anno scolastico corrente, calcolato invece che scritto a mano.
    ///
    /// Era una costante nel sorgente — "A.S. 2025/2026" — e come tutte le
    /// date scritte a mano era gia' scaduta. Il campo si puo' correggere dal
    /// pannello dell'intestazione, ma il guaio e' che nessuno se ne accorge:
    /// il documento esce con l'anno sbagliato e finisce cosi' nel fascicolo
    /// dell'alunno.
    ///
    /// Lo stacco e' al primo agosto, non al primo settembre: e' ad agosto che
    /// i docenti di sostegno preparano il materiale per l'anno che comincia,
    /// e un PEI scritto il 29 agosto riguarda l'anno nuovo, non quello finito.
    nonisolated public static func currentSchoolYear(on date: Date = Date()) -> String {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Rome") ?? .current
        let parti = calendario.dateComponents([.year, .month], from: date)
        guard let anno = parti.year, let mese = parti.month else { return "" }

        let inizio = mese >= 8 ? anno : anno - 1
        return "A.S. \(inizio)/\(inizio + 1)"
    }
}
