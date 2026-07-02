import Foundation

// Single source of truth for the server/device configuration.
// The widget extension cannot import this file (folder-synchronized targets);
// it keeps a minimal private copy of the shared keys in CanvasWidgetStore.
enum CanvasSettings {
    static let appGroupSuiteName = "group.polyforms.canvas"
    static let serverURLKey = "canvas.server.url"
    static let deviceURLKey = "canvas.device.url"
    static let defaultServerURL = "http://192.168.0.165:3000"
    static let defaultDeviceURL = "http://192.168.0.174"

    /// Mirrors the standard-defaults configuration into the App Group so the
    /// widget extension reads the same server URL as the app.
    static func syncToAppGroup() {
        let standard = UserDefaults.standard
        let shared = UserDefaults(suiteName: appGroupSuiteName)
        let serverURL = standard.string(forKey: serverURLKey) ?? defaultServerURL
        let deviceURL = standard.string(forKey: deviceURLKey) ?? defaultDeviceURL
        shared?.set(serverURL, forKey: serverURLKey)
        shared?.set(deviceURL, forKey: deviceURLKey)
    }

    static func save(serverURL: String, deviceURL: String) {
        let standard = UserDefaults.standard
        standard.set(serverURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: serverURLKey)
        standard.set(deviceURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: deviceURLKey)
        syncToAppGroup()
    }

    static func validatedHTTPURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        return url
    }
}
