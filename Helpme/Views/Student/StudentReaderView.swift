import SwiftUI

public struct StudentReaderView: View {
    @Bindable public var appViewModel: AppViewModel
    @Bindable public var studentViewModel: StudentReaderViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(appViewModel: AppViewModel, studentViewModel: StudentReaderViewModel) {
        self.appViewModel = appViewModel
        self.studentViewModel = studentViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar

            // Pausa attiva e traguardo appena preso: sopra al testo, dove
            // si guarda, ma senza rubare la schermata.
            if studentViewModel.phase == .breakSuggested, let activeBreak = studentViewModel.currentBreak {
                activeBreakBanner(activeBreak)
            }
            if let badge = studentViewModel.newlyEarnedBadge {
                badgeBanner(badge)
            }

            readingArea
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: studentViewModel.phase)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: studentViewModel.newlyEarnedBadge)
        // Il materiale si rianalizza quando cambia, non a ogni disegno:
        // rifarlo nel corpo della vista rigenererebbe gli identificativi di
        // domande e nodi, e la risposta scelta non corrisponderebbe a nulla.
        .onAppear { studentViewModel.parseStudyTools(from: appViewModel.generatedContent) }
        .onChange(of: appViewModel.generatedContent) { _, content in
            // Durante lo streaming il testo cambia a ogni token: rianalizzarlo
            // ogni volta significherebbe centinaia di passate complete sul
            // main actor mentre la risposta arriva.
            guard !appViewModel.isGenerating else { return }
            studentViewModel.parseStudyTools(from: content)
        }
        .onChange(of: appViewModel.isGenerating) { _, isGenerating in
            guard !isGenerating else { return }
            studentViewModel.parseStudyTools(from: appViewModel.generatedContent)
        }
        .sheet(item: $studentViewModel.activeSheet) { sheet in
            switch sheet {
            case .mindmap:
                MindmapCardView(
                    viewModel: studentViewModel,
                    settings: appViewModel.accessibilitySettings,
                    onClose: { studentViewModel.activeSheet = nil }
                )
            case .quiz:
                InteractiveQuizView(
                    viewModel: studentViewModel,
                    settings: appViewModel.accessibilitySettings,
                    onClose: { studentViewModel.activeSheet = nil }
                )
            case .badges:
                BadgesModalView(
                    completedSessions: studentViewModel.completedSessions,
                    settings: appViewModel.accessibilitySettings,
                    onClose: { studentViewModel.activeSheet = nil }
                )
            }
        }
    }

    // MARK: - Barra strumenti

    /// La barra si stringe da sé: a finestra piena le etichette sono per
    /// esteso, quando lo spazio manca i pulsanti di studio restano icone.
    /// Prima l'unica cosa che cedeva era il timer, che finiva per mandare
    /// a capo "03:00" carattere per carattere.
    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            toolbarRow(compact: false)
            toolbarRow(compact: true)
        }
        .padding(12)
        .background(Color.appWindowBackground)
        .overlay(Divider(), alignment: .bottom)
    }

    private func toolbarRow(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            Button(action: {
                studentViewModel.toggleSpeech(for: readableContent)
            }) {
                Label(
                    speechButtonTitle(compact: compact),
                    systemImage: appViewModel.audioReader.isSpeaking ? "stop.circle.fill" : "play.circle.fill"
                )
                .font(compact ? .system(size: 13, weight: .semibold) : .headline)
                .lineLimit(1)
                .fixedSize()
            }
            .buttonStyle(.borderedProminent)
            .tint(appViewModel.audioReader.isSpeaking ? .orange : Color.institutional)
            .disabled(appViewModel.generatedContent.isEmpty)
            .accessibilityLabel(appViewModel.audioReader.isSpeaking
                                ? "Ferma la lettura ad alta voce"
                                : "Ascolta il testo con l'evidenziazione karaoke")

            Toggle(isOn: $appViewModel.accessibilitySettings.readingRulerEnabled) {
                Label("Righello", systemImage: "ruler.fill")
                    .font(.subheadline)
                    .labelStyle(AdaptiveLabelStyle(iconOnly: compact))
            }
            .toggleStyle(.button)
            .help("Incornicia una riga alla volta oscurando il resto del testo")
            .accessibilityLabel("Righello di lettura")
            .accessibilityHint("Incornicia una riga alla volta oscurando il resto del testo")

            // Gli strumenti interattivi compaiono solo quando il materiale
            // generato si presta davvero: un pulsante che apre una scheda
            // vuota è peggio di un pulsante assente.
            if studentViewModel.hasMindmap {
                studyToolButton(
                    title: "Mappa",
                    symbol: "point.topleft.down.to.point.bottomright.curvepath",
                    hint: "Apri il materiale come mappa concettuale navigabile",
                    compact: compact
                ) { studentViewModel.activeSheet = .mindmap }
            }

            if studentViewModel.hasQuiz {
                studyToolButton(
                    title: "Quiz",
                    symbol: "checklist",
                    hint: "Mettiti alla prova con le domande generate",
                    compact: compact
                ) { studentViewModel.activeSheet = .quiz }
            }

            Spacer(minLength: 8)

            FocusTimerWidget(viewModel: studentViewModel)
        }
    }

    private func speechButtonTitle(compact: Bool) -> String {
        if appViewModel.audioReader.isSpeaking { return compact ? "Ferma" : "Ferma Lettura" }
        return compact ? "Ascolta" : "Ascolta con Karaoke"
    }

    private func studyToolButton(
        title: String,
        symbol: String,
        hint: String,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .labelStyle(AdaptiveLabelStyle(iconOnly: compact))
                .padding(.horizontal, compact ? 0 : 4)
                .frame(minHeight: 28)
                .fixedSize()
        }
        .buttonStyle(.bordered)
        .tint(Color.institutional)
        // In modalità compatta resta la sola icona: senza suggerimento
        // sarebbe un geroglifico.
        .help(hint)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }

    // MARK: - Pausa attiva

    private func activeBreakBanner(_ activeBreak: ActiveBreak) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: activeBreak.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Sessione completata. \(activeBreak.title).")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                Text(activeBreak.instruction)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        studentViewModel.startBreak()
                    }
                } label: {
                    Text("Pausa di \(activeBreak.seconds / 60) min")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .frame(minHeight: 28)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button("Continua a studiare") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        studentViewModel.skipBreak()
                    }
                }
                .buttonStyle(.bordered)
                .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.blue.opacity(0.09))
        .overlay(Divider(), alignment: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sessione completata. Pausa attiva proposta: \(activeBreak.title). \(activeBreak.instruction)")
    }

    private func badgeBanner(_ badge: FocusBadge) -> some View {
        HStack(spacing: 12) {
            Image(systemName: badge.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nuovo traguardo: \(badge.title)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(badge.caption)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Vedi") { studentViewModel.activeSheet = .badges }
                .buttonStyle(.bordered)
                .font(.system(size: 12, weight: .medium, design: .rounded))

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    studentViewModel.dismissBadgeCelebration()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chiudi la notifica del traguardo")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.10))
        .overlay(Divider(), alignment: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Nuovo traguardo conquistato: \(badge.title). \(badge.caption)")
    }

    // MARK: - Area di lettura

    /// Il materiale come deve arrivare allo studente.
    ///
    /// Il testo grezzo porta i marcatori che servono all'app, `- [x]`
    /// compreso: leggerli qui significherebbe vedere la risposta giusta
    /// prima ancora di aprire il quiz. Il docente continua a vedere
    /// l'originale nel proprio editor.
    private var readableContent: String {
        StudyTextPresenter.readable(appViewModel.generatedContent)
    }

    private var readingArea: some View {
        ZStack {
            if appViewModel.generatedContent.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Nessun materiale didattico generato.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Inserisci il testo nell'editor e clicca su 'Genera Materiale Equipollente'.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
            } else {
                KaraokeTextView(
                    text: appViewModel.audioReader.isSpeaking || appViewModel.audioReader.isPaused
                        ? appViewModel.audioReader.spokenText
                        : readableContent,
                    currentRange: appViewModel.audioReader.currentWordRange,
                    settings: appViewModel.accessibilitySettings
                )
            }

            if appViewModel.accessibilitySettings.readingRulerEnabled && !appViewModel.generatedContent.isEmpty {
                ReadingRulerOverlay(
                    offsetY: $studentViewModel.rulerOffsetY,
                    height: appViewModel.accessibilitySettings.readingRulerHeight
                )
            }
        }
    }
}
