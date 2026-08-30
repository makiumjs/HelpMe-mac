import SwiftUI
import CoreText
import os
enum FontRegistrar {

    private static let logger = Logger(subsystem: "it.lemmly.helpme", category: "fonts")
    private static let bundledFonts: [(file: String, ext: String)] = [
        ("Lexend-Variable", "ttf"),
        ("OpenDyslexic-Regular", "otf"),
        ("OpenDyslexic-Bold", "otf"),
        ("OpenDyslexic-Italic", "otf"),
        ("OpenDyslexic-Bold-Italic", "otf")
    ]

    private static var didRegister = false
    private(set) static var availableFamilies: Set<String> = []
    static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true

        for font in bundledFonts {
            guard let url = Bundle.main.url(forResource: font.file, withExtension: font.ext) else {
                logger.warning("Font non trovato nel bundle: \(font.file).\(font.ext)")
                continue
            }

            var error: Unmanaged<CFError>?
            let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

            if registered {
                if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
                   let first = descriptors.first {
                    let family = CTFontCopyFamilyName(CTFontCreateWithFontDescriptor(first, 12, nil)) as String
                    availableFamilies.insert(family)
                }
            } else if let failure = error?.takeRetainedValue() {
                let code = CFErrorGetCode(failure)
                if code == CTFontManagerError.alreadyRegistered.rawValue {
                    availableFamilies.insert(font.file.components(separatedBy: "-").first ?? font.file)
                } else {
                    logger.error("Registrazione fallita per \(font.file): \(failure.localizedDescription)")
                }
            }
        }
    }
    static func isAvailable(_ family: String) -> Bool {
        if availableFamilies.contains(family) { return true }
        #if os(macOS)
        return NSFontManager.shared.availableFontFamilies.contains(family)
        #else
        return UIFont.familyNames.contains(family)
        #endif
    }
}

#if os(macOS)
import AppKit
#else
import UIKit
#endif
