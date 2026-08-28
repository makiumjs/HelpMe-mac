import Foundation
import SwiftData

public enum PeiDimension: String, Codable, CaseIterable, Sendable {
    case cognitive = "Dimensione Cognitiva, Neuropsicologica e dell'Apprendimento"
    case autonomy = "Dimensione dell'Autonomia e dell'Orientamento"
    case communication = "Dimensione della Comunicazione e dei Linguaggi"
    case relational = "Dimensione della Relazione, Interazione e Socializzazione"

    public var shortLabel: String {
        switch self {
        case .cognitive: return "Cognitiva & Apprendimento"
        case .autonomy: return "Autonomia & Orientamento"
        case .communication: return "Comunicazione & Linguaggi"
        case .relational: return "Relazione & Socializzazione"
        }
    }

    public var iconName: String {
        switch self {
        case .cognitive: return "brain.head.profile"
        case .autonomy: return "figure.walk"
        case .communication: return "bubble.left.and.bubble.right"
        case .relational: return "person.2"
        }
    }
}

/// Voce del diario di bordo GLO, sulle 4 dimensioni ministeriali del D.I. 182/2020.
///
/// Le voci le scrive il docente: nulla viene aggiunto automaticamente
/// al registro dall'app.
@Model
public final class GloLogEntry {
    @Attribute(.unique) public var id: UUID
    public var studentId: UUID
    public var studentName: String
    public var date: Date
    public var topic: String
    public var formatUsed: String
    public var dimensionRaw: String
    public var autonomyLevel: String
    public var notes: String

    public var dimension: PeiDimension {
        get { PeiDimension(rawValue: dimensionRaw) ?? .cognitive }
        set { dimensionRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        studentId: UUID,
        studentName: String,
        date: Date = Date(),
        topic: String,
        formatUsed: String,
        dimension: PeiDimension = .cognitive,
        autonomyLevel: String = "Buona autonomia con guida iniziale",
        notes: String = ""
    ) {
        self.id = id
        self.studentId = studentId
        self.studentName = studentName
        self.date = date
        self.topic = topic
        self.formatUsed = formatUsed
        self.dimensionRaw = dimension.rawValue
        self.autonomyLevel = autonomyLevel
        self.notes = notes
    }
}
