import Foundation
import AVFoundation
import SwiftUI

/// Sintesi vocale con evidenziazione karaoke parola per parola.
///
/// Il sintetizzatore riporta gli intervalli sul testo che sta effettivamente
/// pronunciando, non su quello originale: chi disegna l'evidenziazione deve
/// perciò usare `spokenText`, mai il testo di partenza. Sono due stringhe
/// diverse — la ripulitura del markdown sposta le posizioni — ed è da questo
/// disallineamento che nasceva l'evidenziazione sulla parola sbagliata.
@Observable
@MainActor
public final class AudioReaderService: NSObject, AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()

    public private(set) var isSpeaking: Bool = false
    public private(set) var isPaused: Bool = false
    public private(set) var currentWordRange: NSRange? = nil

    /// Il testo realmente inviato al sintetizzatore, a cui si riferiscono
    /// gli intervalli di `currentWordRange`.
    public private(set) var spokenText: String = ""

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Prepara il testo per la lettura: toglie i simboli del markdown senza
    /// spostare nulla, perché ogni simbolo diventa uno spazio della stessa
    /// lunghezza. Nessun trim: taglierebbe l'inizio e sfaserebbe gli intervalli.
    public static func speakableText(from text: String) -> String {
        text.replacingOccurrences(of: "[*#_`\\[\\]]", with: " ", options: .regularExpression)
    }

    public func speak(text: String, rate: Float = 0.48, pitch: Float = 1.0) {
        if synthesizer.isSpeaking {
            if isPaused {
                synthesizer.continueSpeaking()
                isPaused = false
                isSpeaking = true
            } else {
                stop()
            }
            return
        }

        let readable = AudioReaderService.speakableText(from: text)
        guard !readable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        configureAudioSessionIfNeeded()

        spokenText = readable
        currentWordRange = nil

        let utterance = AVSpeechUtterance(string: readable)
        if let italianVoice = AVSpeechSynthesisVoice(language: "it-IT") {
            utterance.voice = italianVoice
        }
        utterance.rate = rate            // calibrato per DSA (standard 0.48)
        utterance.pitchMultiplier = pitch
        utterance.preUtteranceDelay = 0.1

        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
    }

    public func pause() {
        guard synthesizer.isSpeaking, !isPaused else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
        isSpeaking = false
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isPaused = false
        currentWordRange = nil
    }

    /// Su iPadOS la sintesi vocale resta muta se la sessione audio non è
    /// configurata: `.playback` fa suonare l'app anche con l'interruttore
    /// silenzioso attivo, come serve a uno strumento di lettura assistita.
    private func configureAudioSessionIfNeeded() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // La lettura prosegue comunque: senza sessione il volume segue
            // l'interruttore fisico, ma la voce non viene interrotta.
        }
        #endif
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            self.currentWordRange = characterRange
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            self.isSpeaking = false
            self.isPaused = false
            self.currentWordRange = nil
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            self.isSpeaking = false
            self.isPaused = false
            self.currentWordRange = nil
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            self.isPaused = true
            self.isSpeaking = false
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            self.isPaused = false
            self.isSpeaking = true
        }
    }
}
