//
//  HelpmeApp.swift
//  Helpme
//
//  Suite didattica inclusiva per docenti di sostegno (D.I. 182/2020)
//  e studenti con DSA / ADHD. macOS e iPadOS.
//

import SwiftUI
import SwiftData

@main
struct HelpmeApp: App {

    private let persistence = PersistenceController.shared
    @State private var appViewModel: AppViewModel

    init() {
        // I font inclusi vanno registrati prima che una vista li richieda.
        FontRegistrar.registerBundledFonts()

        let controller = PersistenceController.shared
        _appViewModel = State(
            initialValue: AppViewModel(modelContext: ModelContext(controller.container))
        )
    }

    var body: some Scene {
        WindowGroup {
            MainWorkspaceView(appViewModel: appViewModel)
            #if os(macOS)
                .frame(minWidth: 960, minHeight: 640)
            #endif
        }
        .modelContainer(persistence.container)
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}
