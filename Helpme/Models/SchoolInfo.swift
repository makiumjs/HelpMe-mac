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
        schoolYear: String = "A.S. 2025/2026",
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
}
