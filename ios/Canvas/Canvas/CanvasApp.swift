import SwiftUI

@main
struct CanvasApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UserDefaults.standard.register(defaults: [
            CanvasSettings.serverURLKey: CanvasSettings.defaultServerURL,
            CanvasSettings.deviceURLKey: CanvasSettings.defaultDeviceURL,
        ])
        CanvasSettings.syncToAppGroup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                CanvasSettings.syncToAppGroup()
            }
        }
    }
}
