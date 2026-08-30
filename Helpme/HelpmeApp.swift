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
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, phase in
            // Un'app lasciata aperta sulla cattedra da un giorno all'altro
            // si crederebbe ancora licenziata: lo stato si ricalcola quando
            // torna in primo piano.
            if phase == .active {
                appViewModel.refreshLicenseState()
            } else {
                // L'app sta per passare in secondo piano o chiudersi: il
                // lavoro non deve restare solo in memoria.
                appViewModel.rememberWork()
            }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}
