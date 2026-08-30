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

    /// Il riferimento che compare sui documenti.
    ///
    /// Si cita il testo coordinato: il D.I. 182/2020 e' stato corretto dal
    /// D.I. 153/2023, e citare solo il primo rimanda a un testo non piu'
    /// vigente su un documento che entra nel fascicolo dell'alunno.
    public var legalReference: String {
        switch self {
        case .minimi:
            return "D.I. 182/2020 Art. 15 c. 1 lett. b, come modificato dal D.I. 153/2023 — L. 104/1992"
        case .differenziato:
            return "D.I. 182/2020 Art. 15 c. 1 lett. c, come modificato dal D.I. 153/2023"
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

    /// Il lavoro in corso su questo alunno.
    ///
    /// Vivevano solo in memoria: il docente generava il materiale, chiudeva
    /// l'app, e il lavoro spariva senza che niente lo avvertisse. Ora seguono
    /// la scheda, quindi sopravvivono alla chiusura e tornano quando si
    /// riseleziona l'alunno.
    public var lastSourceText: String = ""
    public var lastGeneratedContent: String = ""

    /// L'ultimo glossario compilato per questo alunno.
    ///
    /// Sta a parte dal materiale in corso perche' serve dopo: la spiegazione
    /// semplificata riusa le parole che il docente ha gia' scelto per lui,
    /// invece di farle riscrivere da capo con parole diverse.
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
