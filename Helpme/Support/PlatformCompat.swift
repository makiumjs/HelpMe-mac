import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Colori di sistema
extension Color {
    static var appControlBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
    static var appTextBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    static var appWindowBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}

// MARK: - Appunti

enum Clipboard {
    static func copy(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }
}

// MARK: - Cartella di esportazione

enum ExportLocation {
    static var documentsDirectory: URL? {
        #if os(macOS)
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        #else
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        #endif
    }
    static var displayName: String {
        #if os(macOS)
        "~/Downloads"
        #else
        "File › Helpme"
        #endif
    }
}

// MARK: - Etichetta che si stringe
struct AdaptiveLabelStyle: LabelStyle {
    let iconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            if !iconOnly { configuration.title }
        }
    }
}

// MARK: - Divisione orizzontale ridimensionabile
struct AdaptiveHSplit<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing
    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }
    var body: some View {
        #if os(macOS)
        HSplitView {
            leading
            trailing
        }
        #else
        HStack(spacing: 0) {
            leading
            Divider()
            trailing
        }
        #endif
    }
}

// MARK: - Stile lista barra laterale

extension View {
    @ViewBuilder
    func appSidebarListStyle() -> some View {
        #if os(macOS)
        self.listStyle(SidebarListStyle())
        #else
        self.listStyle(.insetGrouped)
        #endif
    }
    func draggableCursor() -> some View {
        self.onHover { inside in
            #if os(macOS)
            if inside { NSCursor.openHand.set() } else { NSCursor.arrow.set() }
            #endif
        }
    }
}
