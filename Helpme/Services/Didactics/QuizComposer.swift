import Foundation

/// Scrive il markup di un quiz a partire dalle domande.
///
/// È l'inverso esatto di `QuizParser`: quello legge, questo scrive. Serve
/// perché finora il quiz si poteva ottenere solo da un modello — il markup
/// `- [x] opzione :: spiegazione` a mano non lo digita nessuno, e sbagliare
/// una parentesi quadra significa una domanda che non si può cliccare.
///
/// Il contratto sta in un posto solo, `DidacticMarkup`, e un test verifica
/// che scrivere e rileggere restituisca le stesse domande.
public nonisolated enum QuizComposer {

    public static func compose(_ questions: [QuizQuestion]) -> String {
        guard !questions.isEmpty else { return "" }

        var blocks: [String] = ["## Quiz di autoverifica"]

        for (index, question) in questions.enumerated() {
            var block = "### Domanda \(index + 1)\n\(question.prompt)\n"
            for option in question.options {
                let marker = option.isCorrect ? "[x]" : "[ ]"
                var row = "- \(marker) \(option.text)"
                if let explanation = option.explanation?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !explanation.isEmpty {
                    row += " :: \(explanation)"
                }
                block += "\n" + row
            }
            blocks.append(block)
        }
        return blocks.joined(separator: "\n\n")
    }
}

/// Una domanda in lavorazione nell'editor.
///
/// Separata da `QuizQuestion` perché mentre si scrive è quasi sempre
/// incompleta — nessuna risposta ancora segnata, opzioni vuote — e un tipo
/// che pretende di essere valido costringerebbe a inventare valori finti.
public struct QuizDraftQuestion: Identifiable, Equatable {
    public let id = UUID()
    public var prompt: String = ""
    public var options: [QuizDraftOption] = [
        QuizDraftOption(), QuizDraftOption(), QuizDraftOption(), QuizDraftOption()
    ]
    public var correctIndex: Int? = nil

    public init() {}

    public init(from question: QuizQuestion) {
        prompt = question.prompt
        options = question.options.map { QuizDraftOption(text: $0.text, explanation: $0.explanation ?? "") }
        correctIndex = question.options.firstIndex { $0.isCorrect }
    }

    /// Una domanda si può usare quando ha un testo, almeno due opzioni piene
    /// e una risposta segnata. Prima di allora non finisce nel quiz: uno
    /// studente che clicca e non riceve riscontro smette di fidarsi.
    public var isComplete: Bool {
        !prompt.trimmingCharacters(in: .whitespaces).isEmpty
            && correctIndex != nil
            && filledOptions.count >= 2
            && correctIndex.map { index in
                options.indices.contains(index)
                    && !options[index].text.trimmingCharacters(in: .whitespaces).isEmpty
            } ?? false
    }

    var filledOptions: [QuizDraftOption] {
        options.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    public func asQuizQuestion() -> QuizQuestion? {
        guard isComplete, let correctIndex else { return nil }
        let correctText = options[correctIndex].text

        let converted = filledOptions.map { option in
            QuizOption(
                text: option.text.trimmingCharacters(in: .whitespaces),
                isCorrect: option.text == correctText,
                explanation: option.explanation.trimmingCharacters(in: .whitespaces).isEmpty
                    ? nil : option.explanation.trimmingCharacters(in: .whitespaces)
            )
        }
        return QuizQuestion(prompt: prompt.trimmingCharacters(in: .whitespaces), options: converted)
    }
}

public struct QuizDraftOption: Identifiable, Equatable {
    public let id = UUID()
    public var text: String = ""
    /// Il riscontro che lo studente legge dopo aver risposto. Anche sulle
    /// opzioni sbagliate: deve spiegare l'errore, non solo negarlo.
    public var explanation: String = ""

    public init(text: String = "", explanation: String = "") {
        self.text = text
        self.explanation = explanation
    }
}
