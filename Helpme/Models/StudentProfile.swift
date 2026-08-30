import Foundation
import SwiftData

public nonisolated enum ProgramType: String, Codable, CaseIterable, Sendable, Hashable {
    case minimi = "minimi"
    case differenziato = "differenziato"
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
            return "D.I. 182/2020 Art. 15 c. 1 lett. b, come modificato dal D.I. 153/2023 — L. 104/1992"
        case .differenziato:
            return "D.I. 182/2020 Art. 15 c. 1 lett. c, come modificato dal D.I. 153/2023"
        }
    }
}
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
    public var lastSourceText: String = ""
    public var lastGeneratedContent: String = ""
    public var personalGlossary: String = ""

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
        compensatoryMeasures: [String] = [
            "comp.sintesi-vocale",
            "comp.formulari"
        ],
        dispensatoryMeasures: [String] = [
            "disp.tempi",
            "disp.lettura-alta-voce",
            "disp.dettatura"
        ],
        createdAt: Date = Date(),
        lastSourceText: String = "",
        lastGeneratedContent: String = "",
        personalGlossary: String = ""
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
        self.lastSourceText = lastSourceText
        self.lastGeneratedContent = lastGeneratedContent
        self.personalGlossary = personalGlossary
    }
}
