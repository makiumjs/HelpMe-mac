import SwiftUI
import SwiftData

@main
struct HelpmeApp: App {
    private let persistence = PersistenceController.shared
    @State private var appViewModel: AppViewModel
    @Environment(\.scenePhase) private var scenePhase
    init() {
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
            if phase == .active {
                appViewModel.refreshLicenseState()
            } else {
                appViewModel.rememberWork()
            }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}
