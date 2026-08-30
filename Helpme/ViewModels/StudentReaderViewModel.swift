import Foundation
import SwiftUI
public enum FocusPhase: String, Sendable, Equatable {
    case idle
    case focusing
    case breakSuggested
    case onBreak
}

public enum StudentSheet: String, Identifiable, Sendable {
    case mindmap, quiz, badges
    public var id: String { rawValue }
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
    public private(set) var currentBreak: ActiveBreak? = nil
    public private(set) var newlyEarnedBadge: FocusBadge? = nil
    public var earnedBadges: [FocusBadge] { FocusBadge.earned(afterSessions: completedSessions) }
    public var nextBadge: FocusBadge? { FocusBadge.next(afterSessions: completedSessions) }

    // MARK: - Studio interattivo
    public var activeSheet: StudentSheet? = nil
    // MARK: - Righello di lettura
    public var rulerOffsetY: CGFloat = 120.0
    private var timerTask: Task<Void, Never>? = nil
    private var deadline: Date? = nil
    public var minutesComponent: Int { secondsRemaining / 60 }
    public var secondsComponent: Int { secondsRemaining % 60 }
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
            if secondsRemaining <= 0 { secondsRemaining = selectedPresetMinutes * 60 }
        }
        guard secondsRemaining > 0 else {
            resetTimer(minutes: selectedPresetMinutes)
            return
        }

        resume()
    }
    public func startBreak() {
        guard phase == .breakSuggested, let currentBreak else { return }
        phase = .onBreak
        secondsRemaining = currentBreak.seconds
        resume()
    }
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
    public private(set) var mindmapNodes: [MindmapNode] = []
    public private(set) var quizQuestions: [QuizQuestion] = []
    private var parsedContentSnapshot: String? = nil
    public private(set) var quizSelections: [UUID: UUID] = [:]
    public var quizIndex: Int = 0
    public var collapsedMindmapNodes: Set<UUID> = []
    public func parseStudyTools(from content: String) {
        guard content != parsedContentSnapshot else { return }
        parsedContentSnapshot = content
        mindmapNodes = MindmapParser.parse(content)
        quizQuestions = QuizParser.parse(content)
        quizSelections = [:]
        quizIndex = 0
        collapsedMindmapNodes = []
    }
    public var hasMindmap: Bool {
        mindmapNodes.contains { $0.depth >= 2 } || mindmapNodes.count >= 3
    }
    public var hasQuiz: Bool { !quizQuestions.isEmpty }

    // MARK: - Svolgimento del quiz
    public func answerQuiz(questionId: UUID, optionId: UUID) {
        guard quizSelections[questionId] == nil else { return }
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
