import SwiftUI
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
