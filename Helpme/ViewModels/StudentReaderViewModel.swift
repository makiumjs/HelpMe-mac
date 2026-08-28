import Foundation
import SwiftUI

/// Le fasi del ciclo studio-pausa.
///
/// Prima esisteva solo "in corso / fermo": a fine sessione il timer si
/// azzerava e basta, e la pausa attiva prevista dalla specifica non c'era.
public enum FocusPhase: String, Sendable, Equatable {
    /// Pronto a cominciare.
    case idle
    /// Sessione di studio (eventualmente in pausa manuale).
    case focusing
    /// Sessione finita: la pausa attiva è proposta, non ancora avviata.
    case breakSuggested
    /// Pausa attiva in corso.
    case onBreak
}

@Observable
@MainActor
public final class StudentReaderViewModel {

    public var appViewModel: AppViewModel

    // MARK: - Timer Focus ADHD

    public var selectedPresetMinutes: Int = 15
    public private(set) var completedSessions: Int = 0
    public private(set) var phase: FocusPhase = .idle
    public private(set) var isTimerRunning: Bool = false
    public private(set) var secondsRemaining: Int = 15 * 60

    /// La pausa proposta o in corso.
    public private(set) var currentBreak: ActiveBreak? = nil

    /// Badge appena conquistato, da festeggiare una volta sola.
    public private(set) var newlyEarnedBadge: FocusBadge? = nil

    public var showBadgesModal: Bool = false

    public var earnedBadges: [FocusBadge] { FocusBadge.earned(afterSessions: completedSessions) }
    public var nextBadge: FocusBadge? { FocusBadge.next(afterSessions: completedSessions) }

    // MARK: - Studio interattivo

    public var showMindmap: Bool = false
    public var showQuiz: Bool = false

    // MARK: - Righello di lettura

    public var rulerOffsetY: CGFloat = 120.0

    private var timerTask: Task<Void, Never>? = nil
    /// Istante in cui la fase corrente finisce. Il conteggio si ricava da
    /// qui, così non accumula ritardo come farebbe un decremento al secondo.
    private var deadline: Date? = nil

    public var minutesComponent: Int { secondsRemaining / 60 }
    public var secondsComponent: Int { secondsRemaining % 60 }

    /// Quota di fase già trascorsa, per l'anello di avanzamento.
    public var progressFraction: Double {
        let total = phase == .onBreak || phase == .breakSuggested
            ? (currentBreak?.seconds ?? selectedPresetMinutes * 60)
            : selectedPresetMinutes * 60
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(total - secondsRemaining) / Double(total)))
    }

    public init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    // MARK: - Comandi del timer

    public func toggleFocusTimer() {
        switch phase {
        case .idle, .focusing:
            isTimerRunning ? pauseFocusTimer() : startFocusTimer()
        case .breakSuggested:
            startBreak()
        case .onBreak:
            isTimerRunning ? pauseFocusTimer() : resume()
        }
    }

    public func startFocusTimer() {
        guard !isTimerRunning else { return }

        if phase != .focusing {
            phase = .focusing
            currentBreak = nil
            // Un conteggio residuo si rispetta; solo se è esaurito si
            // riparte dal preset scelto.
            if secondsRemaining <= 0 { secondsRemaining = selectedPresetMinutes * 60 }
        }
        guard secondsRemaining > 0 else {
            resetTimer(minutes: selectedPresetMinutes)
            return
        }

        resume()
    }

    /// Avvia la pausa attiva proposta a fine sessione.
    public func startBreak() {
        guard phase == .breakSuggested, let currentBreak else { return }
        phase = .onBreak
        secondsRemaining = currentBreak.seconds
        resume()
    }

    /// Salta la pausa e torna pronto per un'altra sessione.
    public func skipBreak() {
        guard phase == .breakSuggested || phase == .onBreak else { return }
        stopTicking()
        currentBreak = nil
        phase = .idle
        secondsRemaining = selectedPresetMinutes * 60
    }

    public func pauseFocusTimer() {
        guard isTimerRunning else { return }
        if let deadline {
            secondsRemaining = max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
        }
        stopTicking()
    }

    public func resetTimer(minutes: Int) {
        resetTimer(seconds: minutes * 60, presetMinutes: minutes)
    }

    /// Variante in secondi, non esposta fuori dal modulo: serve a impostare
    /// durate che non sono minuti tondi, cosa che nell'interfaccia non
    /// capita ma nei test è l'unico modo di far scadere una fase davvero
    /// invece di simularne la scadenza.
    func resetTimer(seconds: Int, presetMinutes: Int? = nil) {
        stopTicking()
        if let presetMinutes { selectedPresetMinutes = presetMinutes }
        phase = .idle
        currentBreak = nil
        secondsRemaining = max(0, seconds)
    }

    public func dismissBadgeCelebration() {
        newlyEarnedBadge = nil
    }

    // MARK: - Motore del conteggio

    private func resume() {
        guard secondsRemaining > 0 else { return }

        isTimerRunning = true
        deadline = Date().addingTimeInterval(TimeInterval(secondsRemaining))

        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, self.isTimerRunning, let deadline = self.deadline else { return }

                let remaining = Int(deadline.timeIntervalSinceNow.rounded(.up))
                if remaining <= 0 {
                    self.phaseDidElapse()
                    return
                }
                self.secondsRemaining = remaining
            }
        }
    }

    private func stopTicking() {
        isTimerRunning = false
        deadline = nil
        timerTask?.cancel()
        timerTask = nil
    }

    private func phaseDidElapse() {
        stopTicking()
        secondsRemaining = 0

        switch phase {
        case .focusing:
            completeSession()
        case .onBreak:
            finishBreak()
        case .idle, .breakSuggested:
            break
        }
    }

    private func completeSession() {
        let badgesBefore = FocusBadge.earned(afterSessions: completedSessions)
        completedSessions += 1

        let badgesAfter = FocusBadge.earned(afterSessions: completedSessions)
        newlyEarnedBadge = badgesAfter.first { badge in !badgesBefore.contains(badge) }

        // La pausa viene proposta, non imposta: chi è nel flusso deve poter
        // tirare dritto senza combattere con l'app.
        let suggestion = ActiveBreak.suggestion(afterSession: completedSessions)
        currentBreak = suggestion
        phase = .breakSuggested
        secondsRemaining = suggestion.seconds
    }

    private func finishBreak() {
        currentBreak = nil
        phase = .idle
        secondsRemaining = selectedPresetMinutes * 60
    }

    // MARK: - Lettura vocale

    public func toggleSpeech(for text: String) {
        appViewModel.audioReader.speak(
            text: text,
            rate: appViewModel.accessibilitySettings.speechRate,
            pitch: appViewModel.accessibilitySettings.speechPitch
        )
    }

    // MARK: - Studio interattivo

    /// Mappa e quiz sono **memorizzati**, non ricalcolati a ogni lettura.
    ///
    /// `MindmapNode` e `QuizQuestion` si identificano con un `UUID` creato
    /// dal parser: ri-analizzare il testo a ogni passata di layout ne
    /// genererebbe di nuovi ogni volta, e la risposta appena scelta non
    /// corrisponderebbe più a nessuna opzione — il quiz risulterebbe
    /// incliccabile e la mappa non resterebbe chiusa dove l'hai chiusa.
    public private(set) var mindmapNodes: [MindmapNode] = []
    public private(set) var quizQuestions: [QuizQuestion] = []

    /// Il testo da cui derivano quelli qui sopra.
    private var parsedContentSnapshot: String? = nil

    /// Risposte date, per domanda. Stanno qui e non nella vista così non si
    /// perdono chiudendo e riaprendo la scheda del quiz.
    public private(set) var quizSelections: [UUID: UUID] = [:]
    public var quizIndex: Int = 0

    /// Rami chiusi della mappa, anche questi conservati tra un'apertura e
    /// l'altra.
    public var collapsedMindmapNodes: Set<UUID> = []

    /// Rianalizza il materiale, se è cambiato.
    public func parseStudyTools(from content: String) {
        guard content != parsedContentSnapshot else { return }
        parsedContentSnapshot = content
        mindmapNodes = MindmapParser.parse(content)
        quizQuestions = QuizParser.parse(content)

        // Materiale nuovo, quiz nuovo: tenere le risposte vecchie mostrerebbe
        // punteggi che non appartengono a queste domande.
        quizSelections = [:]
        quizIndex = 0
        collapsedMindmapNodes = []
    }

    /// Vero se il materiale generato si presta a essere navigato come mappa:
    /// serve una gerarchia, non un elenco piatto di due voci.
    public var hasMindmap: Bool {
        mindmapNodes.contains { $0.depth >= 2 } || mindmapNodes.count >= 3
    }

    public var hasQuiz: Bool { !quizQuestions.isEmpty }

    // MARK: - Svolgimento del quiz

    public func answerQuiz(questionId: UUID, optionId: UUID) {
        guard quizSelections[questionId] == nil else { return }   // una sola risposta
        quizSelections[questionId] = optionId
    }

    public func chosenOptionId(for questionId: UUID) -> UUID? {
        quizSelections[questionId]
    }

    public func resetQuiz() {
        quizSelections = [:]
        quizIndex = 0
    }

    public var quizAnsweredCount: Int { quizSelections.count }

    public var quizCorrectCount: Int {
        quizQuestions.reduce(0) { total, question in
            guard let chosenId = quizSelections[question.id],
                  let option = question.options.first(where: { $0.id == chosenId }),
                  option.isCorrect else { return total }
            return total + 1
        }
    }
}
