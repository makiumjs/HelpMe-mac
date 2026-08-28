import Foundation

/// Preferenze dell'app che non sono dati di lavoro: tipografia, tema,
/// velocità di lettura, formato didattico usato per ultimo.
///
/// Stanno in `UserDefaults` e non nell'archivio SwiftData perché sono
/// impostazioni della postazione, non dati dell'alunno.
public enum SettingsStore {

    private enum Key {
        static let accessibility = "it.lemmly.helpme.accessibility-settings"
        static let lastFormat = "it.lemmly.helpme.last-didactic-format"
    }

    private static let defaults = UserDefaults.standard

    // MARK: - Accessibilità

    public static func loadAccessibilitySettings() -> AccessibilitySettings {
        guard let data = defaults.data(forKey: Key.accessibility),
              let decoded = try? JSONDecoder().decode(AccessibilitySettings.self, from: data) else {
            return AccessibilitySettings()
        }
        return decoded
    }

    public static func save(_ settings: AccessibilitySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Key.accessibility)
    }

    // MARK: - Ultimo formato didattico usato

    public static func loadLastFormat() -> DidacticFormat {
        guard let raw = defaults.string(forKey: Key.lastFormat),
              let format = DidacticFormat(rawValue: raw) else {
            return .equipollenteExam
        }
        return format
    }

    public static func save(lastFormat: DidacticFormat) {
        defaults.set(lastFormat.rawValue, forKey: Key.lastFormat)
    }
}
