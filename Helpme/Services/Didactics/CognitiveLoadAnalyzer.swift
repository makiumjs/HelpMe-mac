import Foundation
import NaturalLanguage

public nonisolated struct WordSimplification: Equatable, Sendable {
    public let complexWord: String
    public let suggestedAlternative: String
}

public nonisolated enum CognitiveLoadLevel: String, Sendable, CaseIterable {
    case low = "Carico Basso (Accessibile)"
    case moderate = "Carico Medio (Adeguato)"
    case high = "Carico Elevato (Rischio affaticamento)"
    case excessive = "Carico Eccessivo (Richiede semplificazione)"

    public var iconName: String {
        switch self {
        case .low: return "checkmark.circle.fill"
        case .moderate: return "info.circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .excessive: return "xmark.octagon.fill"
        }
    }
}

public nonisolated struct CognitiveLoadSummary: Equatable, Sendable {
    public let gulpease: Int
    public let totalWords: Int
    public let sentenceCount: Int
    public let averageWordsPerSentence: Int
    public let longSentencesCount: Int
    public let passiveSentencesCount: Int
    public let doubleNegationCount: Int
    public let simplifications: [WordSimplification]
    public let loadLevel: CognitiveLoadLevel
    public let recommendations: [String]
}

public nonisolated enum CognitiveLoadAnalyzer {

    // MARK: - Catalogo Sinonimi Didattici Semplificati
    // Termini burocratici, aulici o complessi frequenti nei testi scolastici,
    // accoppiati a equivalenti ad altissima frequenza (Vocabolario di Base).
    public static let simplifiedDictionary: [String: String] = [
        "altresi": "inoltre",
        "altresì": "inoltre",
        "allorche": "quando",
        "allorché": "quando",
        "obsoleto": "superato",
        "rammentare": "ricordare",
        "delucidare": "spiegare",
        "ottemperare": "rispettare",
        "desistere": "rinunciare",
        "esiguo": "scarso / poco",
        "antecedente": "precedente",
        "incombenza": "compito",
        "repentino": "improvviso",
        "ponderare": "valutare bene",
        "adempiere": "completare",
        "corroborare": "confermare",
        "evincere": "ricavare",
        "fruire": "usare",
        "palesare": "mostrare",
        "ragguagliare": "informare",
        "sovrastante": "superiore",
        "testimoniare": "dimostrare",
        "ulteriore": "altro",
        "ubicato": "situato",
        "conseguire": "ottenere",
        "precludere": "impedire",
        "eludere": "evitare",
        "ottimale": "migliore",
        "medesimo": "stesso",
        "dovizia": "abbondanza",
        "reiterare": "ripetere",
        "sopperire": "rimediare",
        "asserire": "affermare",
        "delineare": "descrivere",
        "peculiare": "particolare",
        "inerente": "riguardante",
        "pertinente": "adatto",
        "esplicitare": "spiegare chiaramente",
        "demandare": "affidare",
        "avvalersi": "usare / farsi aiutare da",
        "disamina": "analisi",
        "disquisire": "discutere",
        "predisporre": "preparare",
        "intraprendere": "iniziare",
        "scaturire": "nascere da"
    ]

    // MARK: - Parole con valenza negativa per rilevare doppie negazioni
    private static let negativeWords: Set<String> = [
        "impossibile", "inutile", "insussistente", "inverosimile", "inadeguato",
        "scorretto", "incapace", "ingiusto", "inesatto", "escludere", "negare",
        "disconoscere", "ignorare", "trascurare", "tralasciare", "mancare",
        "omettere", "dimenticare", "privo", "dissimile", "smentire"
    ]

    // MARK: - Analisi Doppie Negazioni
    public static func hasDoubleNegation(_ sentence: String) -> Bool {
        let words = sentence
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .split { !$0.isLetter }
            .map(String.init)

        for (i, word) in words.enumerated() {
            if word == "non" || word == "senza" || word == "mai" || word == "nessun" || word == "nessuno" {
                // Guarda le prossime 3 parole
                for offset in 1...3 where i + offset < words.count {
                    let next = words[i + offset]
                    if negativeWords.contains(next) || next == "non" || next == "senza" {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - Rilevamento Sinonimi Suggeriti
    public static func findSimplifications(in text: String) -> [WordSimplification] {
        let words = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .split { !$0.isLetter }
            .map(String.init)

        var results: [WordSimplification] = []
        var seen: Set<String> = []

        for w in words {
            if let simple = simplifiedDictionary[w], !seen.contains(w) {
                seen.insert(w)
                results.append(WordSimplification(complexWord: w, suggestedAlternative: simple))
            }
        }
        return results
    }

    // MARK: - Valutazione Globale del Carico Cognitivo
    public static func assess(text: String, isExam: Bool = false) -> CognitiveLoadSummary {
        let report = ReadabilityAnalyzer.analyze(text)
        let totalWords = report.sentences.map(\.wordCount).reduce(0, +)
        let longSentences = report.sentences.filter(\.isTooLong).count
        let passiveSentences = report.sentences.filter(\.hasPassive).count
        let doubleNegations = report.sentences.filter { hasDoubleNegation($0.text) }.count
        let simplifications = findSimplifications(in: text)

        var penalty = 0
        if report.gulpease < 50 { penalty += 35 }
        else if report.gulpease < 65 { penalty += 20 }
        else if report.gulpease < 75 { penalty += 10 }

        if report.averageWords > 22 { penalty += 25 }
        else if report.averageWords > 18 { penalty += 15 }

        if longSentences > 0 { penalty += min(30, longSentences * 8) }
        if doubleNegations > 0 { penalty += min(20, doubleNegations * 10) }
        if passiveSentences > 1 { penalty += min(15, passiveSentences * 5) }
        if !simplifications.isEmpty { penalty += min(15, simplifications.count * 4) }

        let level: CognitiveLoadLevel
        switch penalty {
        case ..<25: level = .low
        case 25..<50: level = .moderate
        case 50..<75: level = .high
        default: level = .excessive
        }

        var recommendations: [String] = []
        if longSentences > 0 {
            recommendations.append("Spezzare le \(longSentences) frasi con più di 20 parole per alleggerire la memoria di lavoro.")
        }
        if doubleNegations > 0 {
            recommendations.append("Riformulare \(doubleNegations) frasi con doppia negazione in affermazioni dirette positive.")
        }
        if passiveSentences > 0 {
            recommendations.append("Convertire le forme passive in frasi attive con soggetto esplicito.")
        }
        if !simplifications.isEmpty {
            let samples = simplifications.prefix(3).map { "«\($0.complexWord)» ➔ «\($0.suggestedAlternative)»" }.joined(separator: ", ")
            recommendations.append("Sostituire i termini complessi con parole ad alta frequenza (es. \(samples)).")
        }
        if isExam && totalWords > 400 {
            recommendations.append("La prova contiene oltre 400 parole: verificare se il tempo concesso è sufficiente per la produzione scritta.")
        }

        return CognitiveLoadSummary(
            gulpease: report.gulpease,
            totalWords: totalWords,
            sentenceCount: report.sentences.count,
            averageWordsPerSentence: report.averageWords,
            longSentencesCount: longSentences,
            passiveSentencesCount: passiveSentences,
            doubleNegationCount: doubleNegations,
            simplifications: simplifications,
            loadLevel: level,
            recommendations: recommendations
        )
    }
}
