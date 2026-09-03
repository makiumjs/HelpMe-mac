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
    public var score: String = ""
    public var minutesAllowed: Int? = nil
    public var minutesUsed: Int? = nil

    public var dimension: PeiDimension {
        get { PeiDimension(rawValue: dimensionRaw) ?? .cognitive }
        set { dimensionRaw = newValue.rawValue }
    }

    public var timeRatioFormatted: String? {
        guard let allowed = minutesAllowed, allowed > 0, let used = minutesUsed else { return nil }
        let pct = Int((Double(used) / Double(allowed) * 100).rounded())
        let diff = allowed - used
        if diff > 0 {
            return "\(used) min usati su \(allowed) concessi (\(pct)% — risparmiati \(diff) min)"
        } else if diff < 0 {
            return "\(used) min usati su \(allowed) concessi (\(pct)% — supero di \(-diff) min)"
        } else {
            return "\(used) min usati su \(allowed) concessi (100% del tempo)"
        }
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
        notes: String = "",
        score: String = "",
        minutesAllowed: Int? = nil,
        minutesUsed: Int? = nil
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
        self.score = score
        self.minutesAllowed = minutesAllowed
        self.minutesUsed = minutesUsed
    }
}
