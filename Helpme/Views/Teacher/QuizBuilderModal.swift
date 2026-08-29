import SwiftUI

/// Scrive un quiz di autoverifica senza passare da un modello.
///
/// Finora il quiz si poteva ottenere solo dall'IA: il markup che il lettore
/// si aspetta a mano non lo digita nessuno. Qui si scrivono le domande, si
/// segna la risposta giusta con un tocco, e l'app produce il markup esatto.
///
/// Riaprendolo si ritrova quello che c'è già: il quiz a schermo viene riletto
/// e rimesso in lavorazione, così si corregge invece di riscriverlo.
public struct QuizBuilderModal: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable public var appViewModel: AppViewModel

    @State private var questions: [QuizDraftQuestion]

    public init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        let existing = QuizParser.parse(appViewModel.generatedContent)
        _questions = State(initialValue: existing.isEmpty
            ? [QuizDraftQuestion()]
            : existing.map(QuizDraftQuestion.init(from:)))
    }

    private var completed: Int { questions.filter(\.isComplete).count }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach($questions) { $question in
                        questionEditor($question, number: (questions.firstIndex(of: question) ?? 0) + 1)
                    }

                    Button {
                        questions.append(QuizDraftQuestion())
                    } label: {
                        Label("Aggiungi una domanda", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.trailing, 6)
            }

            Divider()
            footer
        }
        .padding(22)
        .frame(minWidth: 640, minHeight: 620)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.bubble")
                .font(.title)
                .foregroundColor(Color.institutional)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scrivi il quiz").font(.title2).bold()
                Text("Segna la risposta giusta. La spiegazione la legge lo studente dopo aver risposto, anche quando sbaglia.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Button("Annulla") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Text(completed == questions.count
                 ? "\(Plural.it(completed, "domanda pronta", "domande pronte"))"
                 : "\(completed) di \(questions.count) complete — le altre non finiranno nel quiz")
                .font(.caption)
                .foregroundStyle(completed == questions.count ? .secondary : Color.orange)

            Button("Metti nel materiale") {
                appViewModel.applyQuiz(questions.compactMap { $0.asQuizQuestion() })
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.institutional)
            .keyboardShortcut(.defaultAction)
            .disabled(completed == 0)
        }
    }

    private func questionEditor(_ question: Binding<QuizDraftQuestion>, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Domanda \(number)")
                    .font(.headline)
                if !question.wrappedValue.isComplete {
                    Text("incompleta")
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                }
                Spacer()
                if questions.count > 1 {
                    Button(role: .destructive) {
                        questions.removeAll { $0.id == question.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Elimina la domanda \(number)")
                }
            }

            TextField("Testo della domanda", text: question.prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                HStack(alignment: .top, spacing: 8) {
                    // Un solo segno per domanda: il pallino dice qual è la
                    // risposta giusta, e cliccarne un altro sposta il segno.
                    Button {
                        question.wrappedValue.correctIndex = index
                    } label: {
                        Image(systemName: question.wrappedValue.correctIndex == index
                              ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(question.wrappedValue.correctIndex == index
                                             ? Color.institutional : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Segna questa come risposta giusta")
                    .accessibilityLabel("Risposta giusta: opzione \(index + 1)")

                    VStack(spacing: 5) {
                        TextField("Opzione \(index + 1)", text: option.text)
                            .textFieldStyle(.roundedBorder)
                        TextField("Perché è giusta o sbagliata (facoltativo)", text: option.explanation)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
