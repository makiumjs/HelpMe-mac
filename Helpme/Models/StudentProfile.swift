import Foundation
import SwiftData

public enum ProgramType: String, Codable, CaseIterable, Sendable, Hashable {
    case minimi = "minimi"           // Obiettivi Minimi - Equipollente (Art. 15 c. 1 lett. b D.I. 182/2020)
    case differenziato = "differenziato" // Programmazione Differenziata (Art. 15 c. 1 lett. c D.I. 182/2020)

    public var localizedTitle: String {
        switch self {
        case .minimi:
            return "Obiettivi Minimi (Prove Equipollenti per Diploma - Art. 15 D.I. 182/2020)"
        case .differenziato:
            return "Programmazione Differenziata (Credito Formativo)"
        }
    }

    public var legalReference: String {
        switch self {
        case .minimi:
            return "D.I. 182/2020 Art. 15 c. 1 lett. b - L. 104/1992"
        case .differenziato:
            return "D.I. 182/2020 Art. 15 c. 1 lett. c"
        }
    }
}

/// Scheda alunno persistita su disco.
///
/// Contiene dati personali e sanitari di minori: resta sempre in locale,
/// e verso i servizi cloud viene inviata solo la forma pseudonimizzata
/// prodotta da `PseudonymizedProfile`.
@Model
public final class StudentProfile {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var classInfo: String
    public var programTypeRaw: String
    public var interest: String
    public var notes: String
    public var compensatoryMeasures: [String]
    public var dispensatoryMeasures: [String]
    public var createdAt: Date

    public var programType: ProgramType {
        get { ProgramType(rawValue: programTypeRaw) ?? .minimi }
        set { programTypeRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        classInfo: String,
        programType: ProgramType = .minimi,
        interest: String = "Informatica e Gaming",
        notes: String = "",
        // Riferimenti al catalogo, non diciture scritte a mano: cosi' il
        // documento riporta le parole della normativa e le misure finiscono
        // sotto la voce giusta. I tempi aggiuntivi sono una misura
        // dispensativa (Linee guida 4.4), non uno strumento compensativo.
        compensatoryMeasures: [String] = [
            "comp.sintesi-vocale",
            "comp.formulari"
        ],
        dispensatoryMeasures: [String] = [
            "disp.tempi",
            "disp.lettura-alta-voce",
            "disp.dettatura"
        ],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.classInfo = classInfo
        self.programTypeRaw = programType.rawValue
        self.interest = interest
        self.notes = notes
        self.compensatoryMeasures = compensatoryMeasures
        self.dispensatoryMeasures = dispensatoryMeasures
        self.createdAt = createdAt
    }
}
