import SwiftUI

public struct KaraokeTextView: View {
    public let text: String
    public let currentRange: NSRange?
    public let settings: AccessibilitySettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(text: String, currentRange: NSRange?, settings: AccessibilitySettings) {
        self.text = text
        self.currentRange = currentRange
        self.settings = settings
    }

    private var theme: ColorThemePreset { settings.theme }

    public var body: some View {
        // Nessuno scorrimento automatico dietro la parola in lettura: i tre
        // frammenti (prima, evidenziato, dopo) sono un unico `Text`
        // concatenato, e SwiftUI non permette di ancorare un identificativo
        // a una sua porzione. Servirebbe spezzare il testo in viste separate,
        // cambiando l'impaginazione dell'area di lettura — un prezzo troppo
        // alto per la comodità. Su un testo lungo si scorre a mano.
        ScrollView {
            content
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        if let currentRange, let swiftRange = Range(currentRange, in: text) {
            let before = String(text[..<swiftRange.lowerBound])
            let current = String(text[swiftRange])
            let after = String(text[swiftRange.upperBound...])

            (
                styled(before)
                + highlighted(current)
                + styled(after)
            )
            .lineSpacing(CGFloat(settings.lineSpacing))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: currentRange)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Testo in lettura: \(current)")
        } else if settings.syllableColorsEnabled {
            syllabifiedText
                .lineSpacing(CGFloat(settings.lineSpacing))
                .accessibilityLabel(text)
        } else {
            styled(text)
                .lineSpacing(CGFloat(settings.lineSpacing))
                .textSelection(.enabled)
        }
    }

    // MARK: - Composizione del testo

    private func styled(_ fragment: String) -> Text {
        Text(fragment)
            .font(settings.fontFamily.font(size: CGFloat(settings.fontSize)))
            .foregroundColor(theme.text)
            .tracking(CGFloat(settings.letterSpacing))
    }

    private func highlighted(_ fragment: String) -> Text {
        Text(fragment)
            .font(settings.fontFamily.font(size: CGFloat(settings.fontSize), weight: .bold))
            .foregroundColor(theme.karaokeHighlight)
            .tracking(CGFloat(settings.letterSpacing))
    }

    /// Sillabazione a colori alternati: aiuta a non perdere il segno
    /// dentro le parole lunghe.
    private var syllabifiedText: Text {
        let (first, second) = theme.syllableColors
        var result = Text("")
        var index = 0

        for syllable in ItalianSyllabifier.syllabify(text) {
            let color = index.isMultiple(of: 2) ? first : second
            result = result + Text(syllable)
                .font(settings.fontFamily.font(size: CGFloat(settings.fontSize)))
                .foregroundColor(color)
                .tracking(CGFloat(settings.letterSpacing))
            // Spazi e punteggiatura non contano come sillabe: non fanno
            // avanzare l'alternanza dei colori.
            if syllable.contains(where: \.isLetter) { index += 1 }
        }
        return result
    }
}
