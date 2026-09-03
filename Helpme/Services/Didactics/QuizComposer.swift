import Foundation
public nonisolated enum QuizComposer {

    public static func compose(_ questions: [QuizQuestion]) -> String {
        guard !questions.isEmpty else { return "" }

        var blocks: [String] = ["## Quiz di autoverifica"]

        for (index, question) in questions.enumerated() {
            var block = "### Domanda \(index + 1)\n\(question.prompt)\n"
            for option in question.options where !option.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
public nonisolated struct QuizDraftQuestion: Identifiable, Equatable {
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

public nonisolated struct QuizDraftOption: Identifiable, Equatable {
    public let id = UUID()
    public var text: String = ""
    public var explanation: String = ""

    public init(text: String = "", explanation: String = "") {
        self.text = text
        self.explanation = explanation
    }
}
