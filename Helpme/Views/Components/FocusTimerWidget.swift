import SwiftUI

public struct FocusTimerWidget: View {
    @Bindable public var viewModel: StudentReaderViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(viewModel: StudentReaderViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 14) {
            timeDisplay

            // Durante la pausa attiva i preset di studio non hanno senso.
            if viewModel.phase == .idle || viewModel.phase == .focusing {
                presetButtons
            }

            primaryButton
            badgesButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // Il widget tiene la sua larghezza naturale: sono gli altri
        // controlli della barra a doversi stringere, non l'orologio.
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.appWindowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(phaseTint.opacity(viewModel.phase == .idle ? 0.08 : 0.4), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.phase)
    }

    // MARK: - Conteggio

    private var timeDisplay: some View {
        HStack(spacing: 6) {
            Image(systemName: phaseSymbol)
                .foregroundColor(phaseTint)
                .font(.system(size: 16, weight: .semibold))
                .symbolEffect(.pulse, isActive: viewModel.isTimerRunning)

            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%02d:%02d", viewModel.minutesComponent, viewModel.secondsComponent))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    // In una finestra stretta il conteggio veniva mandato a
                    // capo carattere per carattere: "03:00" diventava tre
                    // righe. L'orologio non si comprime, mai.
                    .fixedSize()

                if viewModel.phase != .idle {
                    Text(phaseLabel)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(phaseTint)
                        .textCase(.uppercase)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.appControlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(timeAccessibilityLabel)
    }

    private var timeAccessibilityLabel: String {
        let time = "\(viewModel.minutesComponent) minuti e \(viewModel.secondsComponent) secondi"
        switch viewModel.phase {
        case .idle:            return "Timer Focus pronto, \(time)"
        case .focusing:        return "Sessione di studio, \(time) rimanenti"
        case .breakSuggested:  return "Sessione completata. Pausa attiva proposta di \(time)"
        case .onBreak:         return "Pausa attiva in corso, \(time) rimanenti"
        }
    }

    // MARK: - Preset

    private var presetButtons: some View {
        HStack(spacing: 4) {
            ForEach([10, 15, 25], id: \.self) { minutes in
                Button(action: {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8)) {
                        viewModel.resetTimer(minutes: minutes)
                    }
                }) {
                    Text("\(minutes)m")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .background(viewModel.selectedPresetMinutes == minutes ? Color.institutional.opacity(0.15) : Color.clear)
                .foregroundColor(viewModel.selectedPresetMinutes == minutes ? Color.institutional : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(viewModel.selectedPresetMinutes == minutes ? Color.institutional : Color.clear, lineWidth: 1)
                )
                .accessibilityLabel("Imposta timer su \(minutes) minuti")
                .accessibilityAddTraits(viewModel.selectedPresetMinutes == minutes ? .isSelected : [])
            }
        }
    }

    // MARK: - Comando principale

    private var primaryButton: some View {
        Button(action: {
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75)) {
                viewModel.toggleFocusTimer()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: primarySymbol)
                Text(primaryTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .tint(phaseTint)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(primaryTitle)
    }

    private var primaryTitle: String {
        switch viewModel.phase {
        case .idle:            return "Avvia Focus"
        case .focusing:        return viewModel.isTimerRunning ? "Pausa" : "Riprendi"
        case .breakSuggested:  return "Fai la pausa"
        case .onBreak:         return viewModel.isTimerRunning ? "Sospendi" : "Riprendi"
        }
    }

    private var primarySymbol: String {
        switch viewModel.phase {
        case .idle:            return "play.fill"
        case .focusing:        return viewModel.isTimerRunning ? "pause.fill" : "play.fill"
        case .breakSuggested:  return "figure.walk"
        case .onBreak:         return viewModel.isTimerRunning ? "pause.fill" : "play.fill"
        }
    }

    // MARK: - Traguardi

    private var badgesButton: some View {
        Button(action: { viewModel.showBadgesModal = true }) {
            HStack(spacing: 4) {
                Image(systemName: viewModel.earnedBadges.isEmpty ? "rosette" : "flame.fill")
                    .foregroundColor(viewModel.earnedBadges.isEmpty ? .secondary : .orange)
                    .font(.caption)
                Text("\(viewModel.completedSessions)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(minHeight: 30)
        }
        .buttonStyle(.plain)
        .background(Color.orange.opacity(viewModel.earnedBadges.isEmpty ? 0.06 : 0.14))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.orange.opacity(viewModel.earnedBadges.isEmpty ? 0.15 : 0.35), lineWidth: 1))
        .help("Apri la bacheca dei traguardi")
        .accessibilityLabel("\(viewModel.completedSessions) sessioni completate, \(viewModel.earnedBadges.count) traguardi. Apri la bacheca")
    }

    // MARK: - Aspetto per fase

    private var phaseTint: Color {
        switch viewModel.phase {
        case .idle:            return Color.institutional
        case .focusing:        return viewModel.isTimerRunning ? .green : .orange
        case .breakSuggested:  return .blue
        case .onBreak:         return .blue
        }
    }

    private var phaseSymbol: String {
        switch viewModel.phase {
        case .idle:            return "timer"
        case .focusing:        return "stopwatch.fill"
        case .breakSuggested:  return "sparkles"
        case .onBreak:         return "figure.walk.motion"
        }
    }

    private var phaseLabel: String {
        switch viewModel.phase {
        case .idle:            return "pronto"
        case .focusing:        return viewModel.isTimerRunning ? "studio" : "in pausa"
        case .breakSuggested:  return "fatto!"
        case .onBreak:         return "pausa attiva"
        }
    }
}
