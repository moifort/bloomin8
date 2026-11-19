import Foundation

/// Single source of truth for the server/device configuration, shared by the
/// app (which edits it) and the widget (which reads it from the App Group).
public enum CanvasSettings {
    public static let appGroupSuiteName = "group.polyforms.canvas"
    public static let serverURLKey = "canvas.server.url"
    public static let deviceURLKey = "canvas.device.url"
    public static let defaultServerURL = "http://canvas.local:3000"
    public static let defaultDeviceURL = "http://192.168.1.182"

    /// UserDefaults of the App Group the app and the widget both read.
    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuiteName)
    }

    /// Server URL as last saved: App Group first, then the app's own defaults.
    public static var serverURL: String {
        sharedDefaults?.string(forKey: serverURLKey)
            ?? UserDefaults.standard.string(forKey: serverURLKey)
            ?? defaultServerURL
    }

    /// Canvas URL as last saved: App Group first, then the app's own defaults.
    public static var deviceURL: String {
        sharedDefaults?.string(forKey: deviceURLKey)
            ?? UserDefaults.standard.string(forKey: deviceURLKey)
            ?? defaultDeviceURL
    }

    /// Mirrors the standard-defaults configuration into the App Group so the
    /// widget extension reads the same server URL as the app.
    public static func syncToAppGroup() {
        let standard = UserDefaults.standard
        let serverURL = standard.string(forKey: serverURLKey) ?? defaultServerURL
        let deviceURL = standard.string(forKey: deviceURLKey) ?? defaultDeviceURL
        sharedDefaults?.set(serverURL, forKey: serverURLKey)
        sharedDefaults?.set(deviceURL, forKey: deviceURLKey)
    }

    public static func save(serverURL: String, deviceURL: String) {
        let standard = UserDefaults.standard
        standard.set(serverURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: serverURLKey)
        standard.set(deviceURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: deviceURLKey)
        syncToAppGroup()
    }

    public static func validatedHTTPURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        return url
    }
}

/// App Group keys of the last known Canvas status, written by the app and the
/// widget (whichever fetched last) so each can show it while offline.
/// Dates are stored as `timeIntervalSince1970` doubles.
public enum CanvasCacheKeys {
    public static let batteryPercentage = "canvas.battery.percentage"
    public static let lastFullChargeDate = "canvas.battery.last-full-charge-date"
    public static let lastPullDate = "canvas.battery.last-pull-date"
    public static let playlistDisplayed = "canvas.playlist.displayed"
    public static let playlistTotal = "canvas.playlist.total"
    public static let nextPullDate = "canvas.playlist.next-pull-date"
}
