import SwiftUI

@main
struct CanvasApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UserDefaults.standard.register(defaults: [
            CanvasSettings.serverURLKey: CanvasSettings.defaultServerURL,
            CanvasSettings.deviceURLKey: CanvasSettings.defaultDeviceURL,
        ])
        Self.syncSettings()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Self.syncSettings()
            }
        }
    }

    private static func syncSettings() {
        let standard = UserDefaults.standard
        let shared = UserDefaults(suiteName: CanvasSettings.appGroupSuiteName)
        let serverURL = standard.string(forKey: CanvasSettings.serverURLKey) ?? CanvasSettings.defaultServerURL
        let deviceURL = standard.string(forKey: CanvasSettings.deviceURLKey) ?? CanvasSettings.defaultDeviceURL
        shared?.set(serverURL, forKey: CanvasSettings.serverURLKey)
        shared?.set(deviceURL, forKey: CanvasSettings.deviceURLKey)
    }
}

enum CanvasSettings {
    static let appGroupSuiteName = "group.polyforms.canvas"
    static let serverURLKey = "canvas.server.url"
    static let deviceURLKey = "canvas.device.url"
    static let defaultServerURL = "http://192.168.0.165:3000"
    static let defaultDeviceURL = "http://192.168.0.174"
}
