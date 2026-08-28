import SwiftUI

/// Estende tema e tipografia scelti dal lettore alle schermate del docente.
///
/// Prima le impostazioni di accessibilità valevano solo per l'area di lettura:
/// chi ha bisogno di un font ad alta leggibilità ne ha bisogno ovunque, anche
/// nei moduli e nella barra laterale.
struct ThemedApp: ViewModifier {
    let settings: AccessibilitySettings

    func body(content: Content) -> some View {
        if settings.applyThemeToWholeApp {
            content
                .font(settings.fontFamily.font(size: 13))
                .foregroundColor(settings.theme.text)
                .tint(settings.theme.accent)
                .background(settings.theme.background)
                .environment(\.colorScheme, settings.theme.colorScheme)
        } else {
            content.tint(.institutional)
        }
    }
}

/// Fondo, tinta e schema di colori per una scheda che dipinge da sé lo
/// sfondo del tema DSA.
///
/// Le schede di studio si presentano come fogli, e un foglio non eredita il
/// tema dell'area di lettura: senza questo, con il tema scuro i pulsanti
/// restavano in stile chiaro sopra un pannello nero.
struct ThemedSurface: ViewModifier {
    let settings: AccessibilitySettings

    func body(content: Content) -> some View {
        content
            .background(settings.theme.background)
            .tint(settings.theme.accent)
            .environment(\.colorScheme, settings.theme.colorScheme)
    }
}

extension View {
    func themedApp(_ settings: AccessibilitySettings) -> some View {
        modifier(ThemedApp(settings: settings))
    }

    func themedSurface(_ settings: AccessibilitySettings) -> some View {
        modifier(ThemedSurface(settings: settings))
    }
}
