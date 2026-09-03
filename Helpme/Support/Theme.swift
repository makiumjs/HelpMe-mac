import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public extension Color {
    /// Colore istituzionale dell'app: verde bosco profondo su sfondo chiaro (#1E4620),
    /// verde salvia luminoso ad alto contrasto su sfondo scuro (#4EBA86).
    static let institutional: Color = {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x4E / 255.0, green: 0xBA / 255.0, blue: 0x86 / 255.0, alpha: 1.0)
                : NSColor(red: 0x1E / 255.0, green: 0x46 / 255.0, blue: 0x20 / 255.0, alpha: 1.0)
        }))
        #else
        return Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0x4E / 255.0, green: 0xBA / 255.0, blue: 0x86 / 255.0, alpha: 1.0)
                : UIColor(red: 0x1E / 255.0, green: 0x46 / 255.0, blue: 0x20 / 255.0, alpha: 1.0)
        })
        #endif
    }()

    /// Tonalità istituzionale intermedia dinamica
    static let institutionalMid: Color = {
        #if os(macOS)
        return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x5D / 255.0, green: 0xC9 / 255.0, blue: 0x95 / 255.0, alpha: 1.0)
                : NSColor(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0, alpha: 1.0)
        }))
        #else
        return Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0x5D / 255.0, green: 0xC9 / 255.0, blue: 0x95 / 255.0, alpha: 1.0)
                : UIColor(red: 0x2E / 255.0, green: 0x7D / 255.0, blue: 0x32 / 255.0, alpha: 1.0)
        })
        #endif
    }()
}
