import XCTest
import SwiftUI
@testable import Helpme

/// La memoizzazione della sillabazione non deve cambiarne il risultato:
/// è un'ottimizzazione, non un cambio di comportamento.
final class SyllabifierMemoTests: XCTestCase {

    func testRepeatedCallsReturnTheSameResult() {
        let text = "Il pistone scende e aspira la miscela di aria e benzina."
        XCTAssertEqual(ItalianSyllabifier.syllabify(text), ItalianSyllabifier.syllabify(text))
    }

    /// Il caso che un memo può rompere: cambiare testo e riottenere quello
    /// vecchio dalla cache.
    func testDifferentTextsGetDifferentResults() {
        let first = ItalianSyllabifier.syllabify("trattore")
        let second = ItalianSyllabifier.syllabify("fotosintesi")
        let firstAgain = ItalianSyllabifier.syllabify("trattore")

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first, firstAgain, "il memo ha restituito il risultato del testo sbagliato")
        XCTAssertEqual(second.joined(), "fotosintesi")
    }

    func testAlternatingTextsStayCorrect() {
        for _ in 0..<20 {
            XCTAssertEqual(ItalianSyllabifier.syllabify("casa").joined(), "casa")
            XCTAssertEqual(ItalianSyllabifier.syllabify("agricoltura").joined(), "agricoltura")
        }
    }
}

@MainActor
final class AccessibilityTests: XCTestCase {

    // MARK: - Font inclusi nell'app

    func testBundledFontsAreRegistered() {
        FontRegistrar.registerBundledFonts()
        XCTAssertTrue(FontRegistrar.isAvailable("Lexend"), "Lexend deve essere nel bundle e registrato")
        XCTAssertTrue(FontRegistrar.isAvailable("OpenDyslexic"), "OpenDyslexic deve essere nel bundle e registrato")
    }

    func testFontFilesArePresentInBundle() {
        for name in ["Lexend-Variable"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "ttf"), "manca \(name).ttf")
        }
        for name in ["OpenDyslexic-Regular", "OpenDyslexic-Bold", "OpenDyslexic-Italic", "OpenDyslexic-Bold-Italic"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "otf"), "manca \(name).otf")
        }
    }

    func testFontLicensesShipWithTheApp() {
        // I font sono sotto SIL OFL: la licenza va distribuita insieme.
        XCTAssertNotNil(Bundle.main.url(forResource: "OFL-Lexend", withExtension: "txt"))
        XCTAssertNotNil(Bundle.main.url(forResource: "OFL-OpenDyslexic", withExtension: "txt"))
    }

    func testEveryFamilyReportsAvailabilityHonestly() {
        FontRegistrar.registerBundledFonts()
        // Nessuna voce deve dichiararsi disponibile ricadendo di nascosto
        // sul font di sistema.
        for family in AccessibleFontFamily.allCases {
            if let bundled = family.bundledFamilyName {
                XCTAssertEqual(family.isAvailable, FontRegistrar.isAvailable(bundled))
            } else {
                XCTAssertTrue(family.isAvailable)
            }
        }
    }

    // MARK: - Impostazioni

    func testSettingsSurviveOlderSavedFormat() throws {
        // Un file salvato prima che esistessero i campi nuovi deve caricarsi.
        let legacy = """
        {"fontFamily":"lexend","fontSize":19,"lineSpacing":8,"letterSpacing":1.2,
         "readingRulerEnabled":false,"readingRulerHeight":48,"speechRate":0.48,
         "speechPitch":1,"theme":"softWarm","syllableColorsEnabled":true}
        """
        let decoded = try JSONDecoder().decode(AccessibilitySettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.fontSize, 19)
        XCTAssertEqual(decoded.theme, .softWarm)
        XCTAssertTrue(decoded.syllableColorsEnabled)
        XCTAssertFalse(decoded.applyThemeToWholeApp, "il campo nuovo prende il valore di default")
    }

    func testThemesDefineDistinctColors() {
        // Ogni tema deve avere un fondo suo: prima i colori erano duplicati
        // in due punti e potevano divergere.
        let backgrounds = ColorThemePreset.allCases.map { $0.background.description }
        XCTAssertEqual(Set(backgrounds).count, ColorThemePreset.allCases.count)
    }

    // MARK: - Sillabazione italiana

    func testSyllabificationOfCommonWords() {
        let cases: [(String, [String])] = [
            ("casa", ["ca", "sa"]),
            ("pistone", ["pi", "sto", "ne"]),
            ("aspirazione", ["a", "spi", "ra", "zio", "ne"]),
            ("carburante", ["car", "bu", "ran", "te"]),
            ("trattore", ["trat", "to", "re"])
        ]
        for (word, expected) in cases {
            XCTAssertEqual(ItalianSyllabifier.syllabifyWord(word), expected, "sillabazione errata per '\(word)'")
        }
    }

    func testDoubleConsonantsSplitBetween() {
        XCTAssertEqual(ItalianSyllabifier.syllabifyWord("mattone"), ["mat", "to", "ne"])
        XCTAssertEqual(ItalianSyllabifier.syllabifyWord("terreno"), ["ter", "re", "no"])
    }

    func testInseparableClustersStayTogether() {
        XCTAssertEqual(ItalianSyllabifier.syllabifyWord("agricolo"), ["a", "gri", "co", "lo"])
        XCTAssertEqual(ItalianSyllabifier.syllabifyWord("macchina"), ["mac", "chi", "na"])
    }

    func testSyllabificationPreservesTheWholeText() {
        let text = "Il pistone scende e aspira la miscela."
        let rebuilt = ItalianSyllabifier.syllabify(text).joined()
        XCTAssertEqual(rebuilt, text, "nessun carattere deve andare perso o essere duplicato")
    }

    func testShortWordsAreLeftAlone() {
        XCTAssertEqual(ItalianSyllabifier.syllabifyWord("il"), ["il"])
        XCTAssertEqual(ItalianSyllabifier.syllabifyWord("che"), ["che"])
    }

    // MARK: - Karaoke

    /// Il difetto originale: il testo pronunciato e quello evidenziato erano
    /// due stringhe diverse, e l'evidenziazione cadeva sulla parola sbagliata.
    func testSpeakableTextKeepsOffsetsAligned() {
        let original = "# Titolo della Verifica\nPrima frase del testo."
        let speakable = AudioReaderService.speakableText(from: original)

        XCTAssertEqual((original as NSString).length, (speakable as NSString).length,
                       "la ripulitura non deve spostare le posizioni")

        // La parola che il sintetizzatore annuncia deve essere quella che si evidenzia.
        let range = NSRange(location: 2, length: 6)
        XCTAssertEqual((speakable as NSString).substring(with: range), "Titolo")
    }

    func testMarkdownSymbolsAreReplacedNotRemoved() {
        let speakable = AudioReaderService.speakableText(from: "**grassetto** e `codice`")
        XCTAssertFalse(speakable.contains("*"))
        XCTAssertFalse(speakable.contains("`"))
        XCTAssertTrue(speakable.contains("grassetto"))
        XCTAssertEqual(speakable.count, "**grassetto** e `codice`".count)
    }
}
