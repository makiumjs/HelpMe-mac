import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Colori di sistema

/// Colori di sistema equivalenti su macOS e iPadOS.
/// Il codice delle viste passa da qui invece di usare NSColor direttamente.
extension Color {
    /// Sfondo dei pannelli di controllo (barre strumenti, widget).
    static var appControlBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    /// Sfondo delle aree di testo editabili.
    static var appTextBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    /// Sfondo della finestra / schermata.
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
    /// Cartella dove salvare i documenti generati.
    /// Su macOS è ~/Downloads, su iPadOS la cartella Documenti dell'app
    /// (visibile in File se l'app dichiara UIFileSharingEnabled).
    static var documentsDirectory: URL? {
        #if os(macOS)
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        #else
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        #endif
    }

    /// Nome leggibile della destinazione, per i messaggi all'utente.
    static var displayName: String {
        #if os(macOS)
        "~/Downloads"
        #else
        "File › Helpme"
        #endif
    }
}

// MARK: - Etichetta che si stringe

/// Titolo e icona quando c'è spazio, sola icona quando manca.
///
/// `.iconOnly` e `.titleAndIcon` sono tipi diversi e non si possono scegliere
/// con una condizione dentro la stessa catena di modificatori: qui la scelta
/// sta dentro un unico stile.
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

/// Su macOS usa HSplitView (divisore trascinabile), su iPadOS un HStack.
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
    /// `.sidebar` esiste solo su macOS; su iPadOS l'equivalente è `.insetGrouped`.
    @ViewBuilder
    func appSidebarListStyle() -> some View {
        #if os(macOS)
        self.listStyle(SidebarListStyle())
        #else
        self.listStyle(.insetGrouped)
        #endif
    }

    /// Mostra la manina sopra un elemento trascinabile.
    ///
    /// Su iPadOS non esiste un puntatore da cambiare e la chiamata non fa
    /// nulla; usa `set()` e non `push()/pop()` perché uno stack di cursori
    /// si sbilancia se il sistema perde l'evento di uscita.
    func draggableCursor() -> some View {
        self.onHover { inside in
            #if os(macOS)
            if inside { NSCursor.openHand.set() } else { NSCursor.arrow.set() }
            #endif
        }
    }
}
