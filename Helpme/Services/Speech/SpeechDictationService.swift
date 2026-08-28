import Foundation
import Speech
import AVFoundation

/// Esito della richiesta di permessi per la dettatura.
///
/// È un tipo a sé, e non lo `SFSpeechRecognizerAuthorizationStatus` di
/// sistema, perché tiene insieme due permessi distinti (riconoscimento e
/// microfono) e la disponibilità della lingua: all'utente interessa una
/// sola risposta chiara, non tre stati da combinare.
public enum DictationPermission: Equatable, Sendable {
    case granted
    case speechDenied
    case microphoneDenied
    case restricted
    case notDetermined
    case unavailableLocale

    /// Messaggio da mostrare, o `nil` se si può procedere.
    public var userMessage: String? {
        switch self {
        case .granted:
            return nil
        case .speechDenied:
            return "Il riconoscimento vocale è disattivato per HelpMe. Attivalo in Impostazioni di Sistema › Privacy e Sicurezza › Riconoscimento vocale."
        case .microphoneDenied:
            return "HelpMe non ha accesso al microfono. Attivalo in Impostazioni di Sistema › Privacy e Sicurezza › Microfono."
        case .restricted:
            return "Il riconoscimento vocale è bloccato da una restrizione del dispositivo (per esempio Tempo di Utilizzo)."
        case .notDetermined:
            return "Permesso per la dettatura non ancora concesso."
        case .unavailableLocale:
            return "Il riconoscimento vocale in italiano non è disponibile su questo dispositivo. Scarica la lingua in Impostazioni di Sistema › Tastiera › Dettatura."
        }
    }

    public var canDictate: Bool { self == .granted }

    /// Traduce lo stato di sistema, tenendo conto se la lingua è utilizzabile.
    public static func from(
        speechStatus: SFSpeechRecognizerAuthorizationStatus,
        microphoneGranted: Bool,
        recognizerAvailable: Bool
    ) -> DictationPermission {
        switch speechStatus {
        case .denied:       return .speechDenied
        case .restricted:   return .restricted
        case .notDetermined: return .notDetermined
        case .authorized:
            guard recognizerAvailable else { return .unavailableLocale }
            return microphoneGranted ? .granted : .microphoneDenied
        @unknown default:
            return .restricted
        }
    }
}

/// Dettatura vocale continua, con trascrizione in tempo reale.
///
/// Prevista dalla specifica come ingresso principale per chi ha disgrafia:
/// scrivere a mano o alla tastiera è la barriera, non il pensiero.
@MainActor
@Observable
public final class SpeechDictationService {

    // MARK: - Stato osservato dalle viste

    public private(set) var isRecording: Bool = false
    /// Testo riconosciuto nella sessione di dettatura in corso.
    public private(set) var liveTranscript: String = ""
    public private(set) var errorMessage: String? = nil
    public private(set) var permission: DictationPermission = .notDetermined

    /// Vero se l'hardware e la lingua ci sono: il pulsante resta visibile
    /// ma disabilitato, invece di sparire senza spiegazione.
    public var isSupported: Bool { recognizer != nil }

    // MARK: - Interni

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Vero tra la richiesta di avvio e il motore audio effettivamente
    /// acceso: copre la finestra in cui `isRecording` è ancora falso ma una
    /// sessione è già in preparazione.
    private var isStarting = false

    public init(locale: Locale = Locale(identifier: "it-IT")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Permessi

    @discardableResult
    public func requestPermission() async -> DictationPermission {
        let speechStatus = await Self.requestSpeechAuthorization()
        let microphoneGranted = await AVCaptureDevice.requestAccess(for: .audio)

        let result = DictationPermission.from(
            speechStatus: speechStatus,
            microphoneGranted: microphoneGranted,
            recognizerAvailable: recognizer?.isAvailable ?? false
        )
        permission = result
        errorMessage = result.userMessage
        return result
    }

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Registrazione

    public func toggle() async {
        isRecording ? stop() : await start()
    }

    public func start() async {
        // `isRecording` diventa vero solo a motore audio avviato, cioè dopo
        // l'attesa dei permessi: un doppio tocco rapido supererebbe quel
        // controllo due volte, e la seconda chiamata smonterebbe la sessione
        // appena avviata dalla prima. Questa bandiera si alza subito, prima
        // di qualunque sospensione.
        guard !isStarting, !isRecording else { return }
        isStarting = true
        defer { isStarting = false }

        guard let recognizer else {
            errorMessage = DictationPermission.unavailableLocale.userMessage
            return
        }

        let permission = await requestPermission()
        guard permission.canDictate else { return }

        // Una sessione precedente lasciata aperta bloccherebbe il motore audio.
        teardown()
        liveTranscript = ""
        errorMessage = nil

        do {
            try configureAudioSession()

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Il parlato non lascia il dispositivo se il modello è locale:
            // per dati di minori è la sola configurazione accettabile.
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.channelCount > 0 else {
                errorMessage = "Nessun microfono disponibile su questo dispositivo."
                teardown()
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.liveTranscript = result.bestTranscription.formattedString
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        // Un errore a dettatura già avviata quasi sempre è la
                        // fine naturale del flusso audio: non va segnalato
                        // come guasto, altrimenti ogni pausa sembra un errore.
                        self.finishRecording()
                    }
                }
            }
        } catch {
            errorMessage = "Impossibile avviare la dettatura: \(error.localizedDescription)"
            teardown()
        }
    }

    public func stop() {
        guard isRecording else { return }
        request?.endAudio()
        finishRecording()
    }

    /// Svuota la trascrizione dopo che è stata consegnata all'editor.
    public func consumeTranscript() -> String {
        let text = liveTranscript
        liveTranscript = ""
        return text
    }

    private func finishRecording() {
        isRecording = false
        teardown()
    }

    private func teardown() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
        deactivateAudioSession()
    }

    // MARK: - Sessione audio (solo iPadOS)

    private func configureAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - Fusione con il testo già scritto

    /// Accoda il dettato al testo esistente senza incollare le parole
    /// insieme e senza accumulare spazi.
    public static func merged(existing: String, dictated: String) -> String {
        let addition = dictated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addition.isEmpty else { return existing }
        guard !existing.isEmpty else { return addition }

        // Se il testo finisce già con uno spazio o va a capo, si rispetta
        // quella spaziatura invece di aggiungerne un'altra.
        if let last = existing.last, last.isWhitespace || last.isNewline {
            return existing + addition
        }
        return existing + " " + addition
    }
}
