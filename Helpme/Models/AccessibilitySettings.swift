import SwiftUI
public enum AccessibleFontFamily: String, CaseIterable, Codable, Sendable {
    case lexend
    case openDyslexic
    case rounded
    case standard

    public var displayName: String {
        switch self {
        case .lexend: return "Lexend — leggibilità e anti-affaticamento"
        case .openDyslexic: return "OpenDyslexic — base appesantita per la dislessia"
        case .rounded: return "Arrotondato di sistema — geometrico e chiaro"
        case .standard: return "Standard di sistema"
        }
    }

    public var explanation: String {
        switch self {
        case .lexend:
            return "Disegnato per ridurre l'affaticamento visivo, con spaziature ampie."
        case .openDyslexic:
            return "Lettere appesantite in basso: impedisce di confondere b/d e p/q."
        case .rounded:
            return "SF Pro Rounded: forme geometriche e alto contrasto."
        case .standard:
            return "Il carattere di sistema, il più familiare."
        }
    }

    public var bundledFamilyName: String? {
        switch self {
        case .lexend: return "Lexend"
        case .openDyslexic: return "OpenDyslexic"
        case .rounded, .standard: return nil
        }
    }

    public var isAvailable: Bool {
        guard let family = bundledFamilyName else { return true }
        return FontRegistrar.isAvailable(family)
    }

    public func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .lexend, .openDyslexic:
            if let family = bundledFamilyName, FontRegistrar.isAvailable(family) {
                return .custom(family, size: size).weight(weight)
            }
            return .system(size: size, weight: weight, design: .rounded)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .standard:
            return .system(size: size, weight: weight, design: .default)
        }
    }
}

public enum ColorThemePreset: String, CaseIterable, Codable, Sendable {
    case defaultTheme
    case softWarm
    case highContrastDark
    case pastelCalm

    public var displayName: String {
        switch self {
        case .defaultTheme: return "Standard — verde foresta"
        case .softWarm: return "Carta calda — anti-riflesso"
        case .highContrastDark: return "Alto contrasto scuro"
        case .pastelCalm: return "Pastello calmante — lavanda e salvia"
        }
    }

    public var background: Color {
        switch self {
        case .defaultTheme:      return Color(hex: 0xF8FAF9)
        case .softWarm:          return Color(hex: 0xFAF8F2)
        case .highContrastDark:  return Color(hex: 0x121413)
        case .pastelCalm:        return Color(hex: 0xF3F4F9)
        }
    }

    public var text: Color {
        switch self {
        case .defaultTheme:      return Color(hex: 0x1A2E22)
        case .softWarm:          return Color(hex: 0x2D261E)
        case .highContrastDark:  return Color(hex: 0xF4F7F5)
        case .pastelCalm:        return Color(hex: 0x212338)
        }
    }

    public var accent: Color {
        switch self {
        case .defaultTheme:      return Color(hex: 0x1E4620)
        case .softWarm:          return Color(hex: 0x8C5E24)
        case .highContrastDark:  return Color(hex: 0x4ADE80)
        case .pastelCalm:        return Color(hex: 0x5C6AC4)
        }
    }

    public var karaokeHighlight: Color {
        switch self {
        case .defaultTheme:      return Color(hex: 0x0D5A1F)
        case .softWarm:          return Color(hex: 0x8C4005)
        case .highContrastDark:  return Color(hex: 0x59F275)
        case .pastelCalm:        return Color(hex: 0x4059D9)
        }
    }

    public var karaokeBackground: Color {
        switch self {
        case .defaultTheme:      return Color(hex: 0xD8F0DC)
        case .softWarm:          return Color(hex: 0xF7E6C8)
        case .highContrastDark:  return Color(hex: 0x25382A)
        case .pastelCalm:        return Color(hex: 0xDDE1F7)
        }
    }

    public var colorScheme: ColorScheme {
        self == .highContrastDark ? .dark : .light
    }

    public var syllableColors: (Color, Color) {
        switch self {
        case .defaultTheme:      return (Color(hex: 0x1A2E22), Color(hex: 0x1462A8))
        case .softWarm:          return (Color(hex: 0x2D261E), Color(hex: 0x9B3B10))
        case .highContrastDark:  return (Color(hex: 0xF4F7F5), Color(hex: 0x62D2F5))
        case .pastelCalm:        return (Color(hex: 0x212338), Color(hex: 0x8A4BAF))
        }
    }
}

public struct AccessibilitySettings: Codable, Sendable, Equatable {
    public var fontFamily: AccessibleFontFamily
    public var fontSize: Double
    public var lineSpacing: Double
    public var letterSpacing: Double
    public var readingRulerEnabled: Bool
    public var readingRulerHeight: Double
    public var speechRate: Float
    public var speechPitch: Float
    public var theme: ColorThemePreset
    public var syllableColorsEnabled: Bool
    public var applyThemeToWholeApp: Bool
    public init(
        fontFamily: AccessibleFontFamily = .lexend,
        fontSize: Double = 17.0,
        lineSpacing: Double = 8.0,
        letterSpacing: Double = 1.2,
        readingRulerEnabled: Bool = false,
        readingRulerHeight: Double = 48.0,
        speechRate: Float = 0.48,
        speechPitch: Float = 1.0,
        theme: ColorThemePreset = .defaultTheme,
        syllableColorsEnabled: Bool = false,
        applyThemeToWholeApp: Bool = false
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.letterSpacing = letterSpacing
        self.readingRulerEnabled = readingRulerEnabled
        self.readingRulerHeight = readingRulerHeight
        self.speechRate = speechRate
        self.speechPitch = speechPitch
        self.theme = theme
        self.syllableColorsEnabled = syllableColorsEnabled
        self.applyThemeToWholeApp = applyThemeToWholeApp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AccessibilitySettings()
        fontFamily = try container.decodeIfPresent(AccessibleFontFamily.self, forKey: .fontFamily) ?? fallback.fontFamily
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? fallback.fontSize
        lineSpacing = try container.decodeIfPresent(Double.self, forKey: .lineSpacing) ?? fallback.lineSpacing
        letterSpacing = try container.decodeIfPresent(Double.self, forKey: .letterSpacing) ?? fallback.letterSpacing
        readingRulerEnabled = try container.decodeIfPresent(Bool.self, forKey: .readingRulerEnabled) ?? fallback.readingRulerEnabled
        readingRulerHeight = try container.decodeIfPresent(Double.self, forKey: .readingRulerHeight) ?? fallback.readingRulerHeight
        speechRate = try container.decodeIfPresent(Float.self, forKey: .speechRate) ?? fallback.speechRate
        speechPitch = try container.decodeIfPresent(Float.self, forKey: .speechPitch) ?? fallback.speechPitch
        theme = try container.decodeIfPresent(ColorThemePreset.self, forKey: .theme) ?? fallback.theme
        syllableColorsEnabled = try container.decodeIfPresent(Bool.self, forKey: .syllableColorsEnabled) ?? fallback.syllableColorsEnabled
        applyThemeToWholeApp = try container.decodeIfPresent(Bool.self, forKey: .applyThemeToWholeApp) ?? fallback.applyThemeToWholeApp
    }
}

// MARK: - Colori da esadecimale

public extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
