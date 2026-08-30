import Foundation
public enum SettingsStore {

    private enum Key {
        static let accessibility = "it.lemmly.helpme.accessibility-settings"
        static let lastFormat = "it.lemmly.helpme.last-didactic-format"
        static let licenseToken = "it.lemmly.helpme.license-token"
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

    // MARK: - Licenza
    public static func loadLicenseToken() -> String? {
        defaults.string(forKey: Key.licenseToken)
    }

    public static func save(licenseToken: String?) {
        guard let licenseToken, !licenseToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            defaults.removeObject(forKey: Key.licenseToken)
            return
        }
        defaults.set(licenseToken.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.licenseToken)
    }
}
