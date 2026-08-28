import SwiftUI

/// Il quiz di autoverifica, con risposte cliccabili e riscontro immediato.
///
/// Prima l'IA generava le domande e restavano testo: lo studente leggeva
/// anche la risposta giusta insieme alla domanda, e l'autoverifica non
/// verificava niente.
public struct InteractiveQuizView: View {
    /// Domande e risposte vivono nel view model: restano quelle anche se la
    /// scheda si chiude, e i loro identificativi non cambiano sotto i piedi
    /// della selezione a ogni passata di layout.
    @Bindable public var viewModel: StudentReaderViewModel
    public let settings: AccessibilitySettings
    public var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        viewModel: StudentReaderViewModel,
        settings: AccessibilitySettings,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.settings = settings
        self.onClose = onClose
    }

    private var questions: [QuizQuestion] { viewModel.quizQuestions }
    private var currentIndex: Int { viewModel.quizIndex }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if questions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        questionCard
                        if isAnswered { feedbackCard }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                footer
            }
        }
        .themedSurface(settings)
        .frame(minWidth: 480, idealWidth: 640, minHeight: 420, idealHeight: 580)
    }

    // MARK: - Domanda corrente

    private var question: QuizQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    private var chosenOptionId: UUID? {
        guard let question else { return nil }
        return viewModel.chosenOptionId(for: question.id)
    }

    private var isAnswered: Bool { chosenOptionId != nil }

    private var chosenOption: QuizOption? {
        guard let question, let chosenOptionId else { return nil }
        return question.options.first { $0.id == chosenOptionId }
    }

    // MARK: - Intestazione

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(settings.theme.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("Quiz di autoverifica")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(settings.theme.text)
                if !questions.isEmpty {
                    Text("Domanda \(currentIndex + 1) di \(questions.count) — \(correctCount) giuste finora")
                        .font(.system(size: 11))
                        .foregroundStyle(settings.theme.text.opacity(0.65))
                }
            }

            Spacer()

            if answeredCount > 0 {
                Button("Ricomincia") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        viewModel.resetQuiz()
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .medium, design: .rounded))
            }

            // Chiudere non è l'azione principale: la protagonista è la
            // domanda. Un pulsante pieno qui ruberebbe la scena.
            Button("Chiudi", action: onClose)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 40))
                .foregroundStyle(settings.theme.text.opacity(0.4))
            Text("Non c'è ancora un quiz da fare.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(settings.theme.text)
            Text("Genera il materiale con il formato «Quiz di Autoverifica»: le domande diventano cliccabili, con la spiegazione dopo ogni risposta.")
                .font(.system(size: 12))
                .foregroundStyle(settings.theme.text.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Scheda della domanda

    @ViewBuilder
    private var questionCard: some View {
        if let question {
            VStack(alignment: .leading, spacing: 14) {
                Text(question.prompt)
                    .font(settings.fontFamily.font(size: CGFloat(settings.fontSize) + 2, weight: .semibold))
                    .tracking(CGFloat(settings.letterSpacing))
                    .lineSpacing(CGFloat(settings.lineSpacing) * 0.6)
                    .foregroundStyle(settings.theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: 8) {
                    ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                        optionRow(question: question, option: option, index: index)
                    }
                }
            }
        }
    }

    private func optionRow(question: QuizQuestion, option: QuizOption, index: Int) -> some View {
        let chosen = chosenOptionId == option.id
        let revealed = isAnswered
        let letter = String(UnicodeScalar(65 + min(index, 25))!)

        return Button {
            guard !isAnswered else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                viewModel.answerQuiz(questionId: question.id, optionId: option.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Circle()
                        .fill(badgeFill(option: option, chosen: chosen, revealed: revealed))
                        .frame(width: markerDiameter, height: markerDiameter)
                    if revealed && option.isCorrect {
                        Image(systemName: "checkmark")
                            .font(.system(size: markerDiameter * 0.46, weight: .bold))
                            .foregroundStyle(.white)
                    } else if revealed && chosen {
                        Image(systemName: "xmark")
                            .font(.system(size: markerDiameter * 0.46, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text(letter)
                            .font(.system(size: markerDiameter * 0.46, weight: .bold, design: .rounded))
                            .foregroundStyle(settings.theme.text.opacity(0.8))
                    }
                }

                Text(option.text)
                    .font(settings.fontFamily.font(size: CGFloat(settings.fontSize)))
                    .tracking(CGFloat(settings.letterSpacing))
                    .foregroundStyle(settings.theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            // 44pt di altezza minima: il requisito di target tattile.
            .frame(minHeight: 44)
            .background(rowFill(option: option, chosen: chosen, revealed: revealed))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(rowStroke(option: option, chosen: chosen, revealed: revealed), lineWidth: revealed && (option.isCorrect || chosen) ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Non `.disabled()`: SwiftUI ne sbiadirebbe la label, e dopo la
        // risposta il testo più importante da leggere — quello corretto —
        // sarebbe quello con meno contrasto. Qui si toglie solo il tocco.
        .allowsHitTesting(!isAnswered)
        .accessibilityLabel("Risposta \(letter): \(option.text)")
        .accessibilityHint(isAnswered ? statusWord(option: option, chosen: chosen) : "Tocca per rispondere")
        .accessibilityAddTraits(.isButton)
    }

    /// Il pallino con la lettera cresce insieme al testo: a 28pt un cerchio
    /// da 26 sembrerebbe un residuo.
    private var markerDiameter: CGFloat {
        max(26, CGFloat(settings.fontSize) + 9)
    }

    private func statusWord(option: QuizOption, chosen: Bool) -> String {
        if option.isCorrect { return "Risposta corretta" }
        return chosen ? "La tua risposta, sbagliata" : "Risposta sbagliata"
    }

    // I colori dell'esito non si affidano solo alla tinta: c'è sempre anche
    // un simbolo, perché il verde e il rosso non li distinguono tutti.
    private func badgeFill(option: QuizOption, chosen: Bool, revealed: Bool) -> Color {
        guard revealed else { return settings.theme.text.opacity(0.12) }
        if option.isCorrect { return Color(hex: 0x1B7F3B) }
        if chosen { return Color(hex: 0xB3261E) }
        return settings.theme.text.opacity(0.12)
    }

    private func rowFill(option: QuizOption, chosen: Bool, revealed: Bool) -> Color {
        guard revealed else { return settings.theme.text.opacity(0.05) }
        if option.isCorrect { return Color(hex: 0x1B7F3B).opacity(0.13) }
        if chosen { return Color(hex: 0xB3261E).opacity(0.11) }
        return settings.theme.text.opacity(0.04)
    }

    private func rowStroke(option: QuizOption, chosen: Bool, revealed: Bool) -> Color {
        guard revealed else { return settings.theme.text.opacity(0.18) }
        if option.isCorrect { return Color(hex: 0x1B7F3B) }
        if chosen { return Color(hex: 0xB3261E) }
        return settings.theme.text.opacity(0.12)
    }

    // MARK: - Riscontro

    @ViewBuilder
    private var feedbackCard: some View {
        if let question, let chosen = chosenOption {
            let correct = question.correctOption
            let gotItRight = chosen.isCorrect

            VStack(alignment: .leading, spacing: 8) {
                Label(
                    gotItRight ? "Esatto." : "Non era questa.",
                    systemImage: gotItRight ? "checkmark.seal.fill" : "lightbulb.fill"
                )
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(gotItRight ? Color(hex: 0x1B7F3B) : Color(hex: 0x8A5A0B))

                if !gotItRight, let correct {
                    Text("La risposta giusta era: \(correct.text)")
                        .font(settings.fontFamily.font(size: CGFloat(settings.fontSize) - 1, weight: .semibold))
                        .foregroundStyle(settings.theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Prima la spiegazione della scelta fatta, poi quella della
                // risposta giusta: capire l'errore vale più della soluzione.
                if let explanation = chosen.explanation {
                    Text(explanation)
                        .font(settings.fontFamily.font(size: CGFloat(settings.fontSize) - 1))
                        .tracking(CGFloat(settings.letterSpacing))
                        .foregroundStyle(settings.theme.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !gotItRight, let correctExplanation = correct?.explanation, correctExplanation != chosen.explanation {
                    Text(correctExplanation)
                        .font(settings.fontFamily.font(size: CGFloat(settings.fontSize) - 1))
                        .tracking(CGFloat(settings.letterSpacing))
                        .foregroundStyle(settings.theme.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((gotItRight ? Color(hex: 0x1B7F3B) : Color(hex: 0x8A5A0B)).opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke((gotItRight ? Color(hex: 0x1B7F3B) : Color(hex: 0x8A5A0B)).opacity(0.35), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Navigazione

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    viewModel.quizIndex = max(0, currentIndex - 1)
                }
            } label: {
                Label("Precedente", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .buttonStyle(.bordered)
            .disabled(currentIndex == 0)

            // Avanzamento leggibile anche senza contare le domande.
            ProgressView(value: Double(answeredCount), total: Double(max(1, questions.count)))
                .tint(settings.theme.accent)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Avanzamento: \(answeredCount) domande su \(questions.count) completate")

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    viewModel.quizIndex = min(questions.count - 1, currentIndex + 1)
                }
            } label: {
                Label("Successiva", systemImage: "chevron.right")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.theme.accent)
            .disabled(currentIndex >= questions.count - 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var answeredCount: Int { viewModel.quizAnsweredCount }
    private var correctCount: Int { viewModel.quizCorrectCount }
}
