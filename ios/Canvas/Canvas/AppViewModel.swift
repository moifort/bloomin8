import Foundation
import Observation
import Photos

@MainActor
@Observable
final class AppViewModel {
    private static let serverURLDefaultsKey = "canvas.server.url"
    private static let canvasURLDefaultsKey = "canvas.device.url"
    private static let batteryPercentageDefaultsKey = "canvas.battery.percentage"
    private static let lastFullChargeDateDefaultsKey = "canvas.battery.last-full-charge-date"
    private static let lastPullDateDefaultsKey = "canvas.battery.last-pull-date"
    private static let sharedDefaultsSuiteName = "group.polyforms.canvas"
    private static let defaultServerURL = "http://192.168.0.165:3000"
    private static let defaultCanvasURL = "http://192.168.0.174"

    private(set) var authorizationStatus: PHAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    private(set) var albums: [PhotoAlbum] = []
    var selectedAlbumId: String?
    var serverURL: String {
        didSet {
            persistServerURL()
        }
    }
    var canvasURL: String {
        didSet {
            persistCanvasURL()
        }
    }
    var cronIntervalInHours: String = "3"

    private(set) var isUploading = false
    private(set) var isStartingPlaylist = false
    private(set) var progress = UploadProgress.empty
    private(set) var statusText: String = ""
    private(set) var errorText: String?
    private(set) var canvasBatteryPercentage: Int? {
        didSet {
            persistCanvasBatteryPercentage()
        }
    }
    private(set) var lastFullChargeDate: Date? {
        didSet {
            persistLastFullChargeDate()
        }
    }
    private(set) var lastFullChargeDays: Int?
    private(set) var lastPullDate: Date? {
        didSet {
            persistLastPullDate()
        }
    }

    private let maxConcurrentUploads = 5
    private let userDefaults: UserDefaults
    private let sharedDefaults: UserDefaults?

    private var uploadTask: Task<Void, Never>?
    private var playlistStartTask: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.sharedDefaults = UserDefaults(suiteName: Self.sharedDefaultsSuiteName)
        self.serverURL = userDefaults.string(forKey: Self.serverURLDefaultsKey) ?? Self.defaultServerURL
        self.canvasURL = userDefaults.string(forKey: Self.canvasURLDefaultsKey) ?? Self.defaultCanvasURL

        if let cached = userDefaults.object(forKey: Self.batteryPercentageDefaultsKey) as? Int {
            self.canvasBatteryPercentage = cached
        }
        if let timestamp = userDefaults.object(forKey: Self.lastFullChargeDateDefaultsKey) as? Double {
            let date = Date(timeIntervalSince1970: timestamp)
            self.lastFullChargeDate = date
            self.lastFullChargeDays = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        }
        if let timestamp = userDefaults.object(forKey: Self.lastPullDateDefaultsKey) as? Double {
            self.lastPullDate = Date(timeIntervalSince1970: timestamp)
        }

        persistServerURL()
        persistCanvasURL()
    }

    var isPhotoAccessGranted: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var canStartUpload: Bool {
        isPhotoAccessGranted && selectedAlbumId != nil && !isUploading && !isStartingPlaylist
    }

    var canStartPlaylist: Bool {
        !isUploading && !isStartingPlaylist
    }

    func bootstrap() async {
        authorizationStatus = PhotoLibraryService.authorizationStatus()
        if !isPhotoAccessGranted {
            authorizationStatus = await PhotoLibraryService.requestAuthorization()
        }

        await refreshCanvasBattery()
        guard isPhotoAccessGranted else { return }
        reloadAlbums()
    }

    func refreshCanvasBattery() async {
        guard let baseURL = validatedHTTPURL(serverURL) else {
            canvasBatteryPercentage = nil
            lastFullChargeDate = nil
            lastFullChargeDays = nil
            lastPullDate = nil
            return
        }

        let service = CanvasStatusService(baseURL: baseURL)
        do {
            if let batteryData = try await service.getBatteryData() {
                canvasBatteryPercentage = batteryData.percentage

                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let lastChargeDateString = batteryData.lastFullChargeDate,
                   let lastChargeDate = dateFormatter.date(from: lastChargeDateString) {
                    self.lastFullChargeDate = lastChargeDate
                    let days = Calendar.current.dateComponents([.day], from: lastChargeDate, to: Date()).day ?? 0
                    lastFullChargeDays = days
                } else {
                    lastFullChargeDate = nil
                    lastFullChargeDays = nil
                }

                if let lastPullDateString = batteryData.lastPullDate,
                   let pullDate = dateFormatter.date(from: lastPullDateString) {
                    self.lastPullDate = pullDate
                } else {
                    lastPullDate = nil
                }
            } else {
                canvasBatteryPercentage = nil
                lastFullChargeDate = nil
                lastFullChargeDays = nil
                lastPullDate = nil
            }
        } catch {
            canvasBatteryPercentage = nil
            lastFullChargeDate = nil
            lastFullChargeDays = nil
            lastPullDate = nil
        }
    }

    func requestPhotoAccess() {
        Task {
            authorizationStatus = await PhotoLibraryService.requestAuthorization()
            guard isPhotoAccessGranted else {
                errorText = String(localized: "Accès Photos refusé.")
                return
            }

            errorText = nil
            reloadAlbums()
        }
    }

    func reloadAlbums() {
        let loadedAlbums = PhotoLibraryService.fetchAlbums()
        albums = loadedAlbums

        guard !loadedAlbums.isEmpty else {
            selectedAlbumId = nil
            return
        }

        if let current = selectedAlbumId, loadedAlbums.contains(where: { $0.id == current }) {
            return
        }

        selectedAlbumId = loadedAlbums.first?.id
    }

    func startUpload() {
        errorText = nil

        guard let selectedAlbumId else {
            errorText = AppError.missingAlbumSelection.localizedDescription
            return
        }

        guard let url = validatedHTTPURL(serverURL) else {
            errorText = AppError.invalidServerURL.localizedDescription
            return
        }

        uploadTask?.cancel()
        uploadTask = Task {
            await runUpload(albumId: selectedAlbumId, baseURL: url)
        }
    }

    func cancelUpload() {
        uploadTask?.cancel()
        uploadTask = nil
    }

    func startPlaylist() {
        errorText = nil

        guard let url = validatedHTTPURL(serverURL) else {
            errorText = AppError.invalidServerURL.localizedDescription
            return
        }
        guard let canvasEndpoint = validatedHTTPURL(canvasURL) else {
            errorText = String(localized: "URL Canvas invalide.")
            return
        }
        guard let parsedCronIntervalInHours = validatedPositiveInt(cronIntervalInHours) else {
            errorText = String(localized: "Intervalle cron invalide (entier > 0 requis).")
            return
        }

        playlistStartTask?.cancel()
        playlistStartTask = Task {
            await runPlaylistStart(
                baseURL: url,
                canvasURL: canvasEndpoint,
                cronIntervalInHours: parsedCronIntervalInHours
            )
        }
    }

    private func runUpload(albumId: String, baseURL: URL) async {
        isUploading = true
        progress = .empty
        statusText = String(localized: "Lecture de l'album...")
        errorText = nil

        defer {
            isUploading = false
            uploadTask = nil
        }

        let assets = PhotoLibraryService.fetchPhotoAssets(in: albumId)
        guard !assets.isEmpty else {
            errorText = AppError.noPhotosInAlbum.localizedDescription
            return
        }

        statusText = String(localized: "Suppression des photos serveur...")
        let imageService = ImageService(baseURL: baseURL)
        do {
            _ = try await imageService.deleteAll()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }

        if Task.isCancelled {
            statusText = String(localized: "Upload annulé.")
            return
        }

        statusText = String(localized: "Upload en cours...")
        let uploader = UploadService(baseURL: baseURL)
        progress = UploadProgress(total: assets.count, processed: 0, uploaded: 0, failed: 0)

        let concurrencyLimit = min(maxConcurrentUploads, assets.count)
        var nextAssetIndex = 0

        await withTaskGroup(of: UploadItemResult.self) { group in
            while nextAssetIndex < concurrencyLimit {
                let asset = assets[nextAssetIndex]
                nextAssetIndex += 1
                group.addTask {
                    await AppViewModel.uploadAsset(asset, uploader: uploader)
                }
            }

            while let itemResult = await group.next() {
                if Task.isCancelled {
                    group.cancelAll()
                    statusText = String(localized: "Upload annulé.")
                    return
                }

                switch itemResult {
                case .uploaded:
                    progress.uploaded += 1
                case .failed:
                    progress.failed += 1
                case .cancelled:
                    break
                }

                progress.processed += 1
                statusText = String(localized: "Upload \(progress.processed)/\(progress.total)")

                if nextAssetIndex < assets.count {
                    let asset = assets[nextAssetIndex]
                    nextAssetIndex += 1
                    group.addTask {
                        await AppViewModel.uploadAsset(asset, uploader: uploader)
                    }
                }
            }
        }

        if Task.isCancelled {
            statusText = String(localized: "Upload annulé.")
            return
        }

        statusText = String(localized: "Terminé : \(progress.uploaded) envoyées, \(progress.failed) échecs.")
    }

    private enum UploadItemResult {
        case uploaded
        case failed
        case cancelled
    }

    private static func uploadAsset(_ asset: PHAsset, uploader: UploadService) async -> UploadItemResult {
        if Task.isCancelled {
            return .cancelled
        }

        do {
            let sourceImage = try await PhotoLibraryService.requestUIImage(for: asset)
            if Task.isCancelled {
                return .cancelled
            }

            guard let processedImage = autoreleasepool(invoking: {
                ImageProcessor.processForUpload(sourceImage)
            }) else {
                return .failed
            }

            _ = try await uploader.uploadJPEG(
                processedImage.jpegData,
                orientation: processedImage.orientation.rawValue
            )
            return .uploaded
        } catch {
            return Task.isCancelled ? .cancelled : .failed
        }
    }

    private func runPlaylistStart(
        baseURL: URL,
        canvasURL: URL,
        cronIntervalInHours: Int
    ) async {
        isStartingPlaylist = true
        statusText = String(localized: "Lancement de la playlist...")
        errorText = nil

        defer {
            isStartingPlaylist = false
            playlistStartTask = nil
        }

        let service = PlaylistService(baseURL: baseURL)
        do {
            statusText = try await service.start(
                canvasURL: canvasURL,
                cronIntervalInHours: cronIntervalInHours
            )
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        await refreshCanvasBattery()
    }

    private func validatedHTTPURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        return url
    }

    private func validatedPositiveInt(_ rawValue: String) -> Int? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedValue = Int(trimmed), parsedValue > 0 else {
            return nil
        }
        return parsedValue
    }

    private func persistServerURL() {
        userDefaults.set(serverURL, forKey: Self.serverURLDefaultsKey)
        sharedDefaults?.set(serverURL, forKey: Self.serverURLDefaultsKey)
    }

    private func persistCanvasURL() {
        userDefaults.set(canvasURL, forKey: Self.canvasURLDefaultsKey)
        sharedDefaults?.set(canvasURL, forKey: Self.canvasURLDefaultsKey)
    }

    private func persistCanvasBatteryPercentage() {
        guard let canvasBatteryPercentage else {
            userDefaults.removeObject(forKey: Self.batteryPercentageDefaultsKey)
            sharedDefaults?.removeObject(forKey: Self.batteryPercentageDefaultsKey)
            return
        }
        userDefaults.set(canvasBatteryPercentage, forKey: Self.batteryPercentageDefaultsKey)
        sharedDefaults?.set(canvasBatteryPercentage, forKey: Self.batteryPercentageDefaultsKey)
    }

    private func persistLastFullChargeDate() {
        guard let lastFullChargeDate else {
            userDefaults.removeObject(forKey: Self.lastFullChargeDateDefaultsKey)
            sharedDefaults?.removeObject(forKey: Self.lastFullChargeDateDefaultsKey)
            return
        }
        let timestamp = lastFullChargeDate.timeIntervalSince1970
        userDefaults.set(timestamp, forKey: Self.lastFullChargeDateDefaultsKey)
        sharedDefaults?.set(timestamp, forKey: Self.lastFullChargeDateDefaultsKey)
    }

    private func persistLastPullDate() {
        guard let lastPullDate else {
            userDefaults.removeObject(forKey: Self.lastPullDateDefaultsKey)
            sharedDefaults?.removeObject(forKey: Self.lastPullDateDefaultsKey)
            return
        }
        let timestamp = lastPullDate.timeIntervalSince1970
        userDefaults.set(timestamp, forKey: Self.lastPullDateDefaultsKey)
        sharedDefaults?.set(timestamp, forKey: Self.lastPullDateDefaultsKey)
    }
}
