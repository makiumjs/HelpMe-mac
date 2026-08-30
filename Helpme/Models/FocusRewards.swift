import Foundation

public struct FocusBadge: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let requiredSessions: Int
    public let symbol: String
    public let caption: String

    public init(id: String, title: String, requiredSessions: Int, symbol: String, caption: String) {
        self.id = id
        self.title = title
        self.requiredSessions = requiredSessions
        self.symbol = symbol
        self.caption = caption
    }

    public static let catalog: [FocusBadge] = [
        FocusBadge(
            id: "primo-traguardo",
            title: "Primo Traguardo",
            requiredSessions: 1,
            symbol: "flag.checkered",
            caption: "Hai portato a termine la tua prima sessione di studio."
        ),
        FocusBadge(
            id: "campione-focus",
            title: "Campione di Focus",
            requiredSessions: 3,
            symbol: "target",
            caption: "Tre sessioni complete: stai prendendo il ritmo."
        ),
        FocusBadge(
            id: "costanza-acciaio",
            title: "Costanza d'Acciaio",
            requiredSessions: 5,
            symbol: "shield.lefthalf.filled",
            caption: "Cinque sessioni. La costanza conta più della velocità."
        ),
        FocusBadge(
            id: "maratoneta",
            title: "Maratoneta dello Studio",
            requiredSessions: 10,
            symbol: "figure.run",
            caption: "Dieci sessioni complete: un traguardo vero."
        )
    ]

    public static func earned(afterSessions sessions: Int) -> [FocusBadge] {
        catalog.filter { sessions >= $0.requiredSessions }
    }

    public static func next(afterSessions sessions: Int) -> FocusBadge? {
        catalog.first { sessions < $0.requiredSessions }
    }
}

public struct ActiveBreak: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let instruction: String
    public let symbol: String
    public let seconds: Int

    public init(id: String, title: String, instruction: String, symbol: String, seconds: Int) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.symbol = symbol
        self.seconds = seconds
    }

    public static let catalog: [ActiveBreak] = [
        ActiveBreak(
            id: "sgranchisci",
            title: "Sgranchisci le gambe",
            instruction: "Alzati dalla sedia e fai venti passi, anche solo avanti e indietro nella stanza.",
            symbol: "figure.walk",
            seconds: 180
        ),
        ActiveBreak(
            id: "occhi",
            title: "Riposa gli occhi",
            instruction: "Guarda fuori dalla finestra, verso qualcosa di lontano, e conta fino a venti senza fretta.",
            symbol: "eye",
            seconds: 120
        ),
        ActiveBreak(
            id: "acqua",
            title: "Bevi un bicchiere d'acqua",
            instruction: "Vai a prendere dell'acqua e bevila in piedi, senza guardare schermi.",
            symbol: "drop",
            seconds: 120
        ),
        ActiveBreak(
            id: "respiro",
            title: "Respira lentamente",
            instruction: "Inspira contando fino a quattro, trattieni fino a quattro, espira fino a sei. Ripeti cinque volte.",
            symbol: "wind",
            seconds: 150
        ),
        ActiveBreak(
            id: "spalle",
            title: "Sciogli le spalle",
            instruction: "Ruota le spalle indietro dieci volte, poi allunga le braccia sopra la testa.",
            symbol: "figure.flexibility",
            seconds: 120
        )
    ]

    public static func suggestion(afterSession sessionNumber: Int) -> ActiveBreak {
        guard !catalog.isEmpty else {
            return ActiveBreak(id: "pausa", title: "Pausa", instruction: "Stacca per qualche minuto.", symbol: "pause", seconds: 120)
        }
        let index = max(0, sessionNumber - 1) % catalog.count
        return catalog[index]
    }
}
