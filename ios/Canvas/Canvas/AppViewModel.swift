import CanvasShared
import Foundation
import Observation
import Photos
import WidgetKit

@MainActor
@Observable
final class AppViewModel {
    // Status cache keys are shared with the widget (CanvasCacheKeys); quiet
    // hours are app-only settings.
    private static let quietHoursEnabledDefaultsKey = "canvas.quiet-hours.enabled"
    // Last timezone sent to the server, to re-push when the iPhone's changes.
    private static let quietHoursTimezoneDefaultsKey = "canvas.quiet-hours.timezone"
    private static let quietHoursStartDefaultsKey = "canvas.quiet-hours.start"
    private static let quietHoursEndDefaultsKey = "canvas.quiet-hours.end"

    private(set) var authorizationStatus: PHAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    private(set) var albums: [PhotoAlbum] = []
    var selectedAlbumId: String?
    private(set) var serverURL: String
    private(set) var canvasURL: String
    var cronIntervalInHours: Int = 3
    var quietHoursEnabled: Bool {
        didSet {
            persistQuietHoursEnabled()
            pushQuietHours()
        }
    }
    var quietHoursStart: Int {
        didSet {
            userDefaults.set(quietHoursStart, forKey: Self.quietHoursStartDefaultsKey)
            pushQuietHours()
        }
    }
    var quietHoursEnd: Int {
        didSet {
            userDefaults.set(quietHoursEnd, forKey: Self.quietHoursEndDefaultsKey)
            pushQuietHours()
        }
    }

    enum UploadOutcome {
        case success
        case failure
    }

    private(set) var isUploading = false
    private(set) var isStartingPlaylist = false
    private(set) var isPausingPlaylist = false
    private(set) var progress = UploadProgress.empty
    private(set) var statusText: String = ""
    private(set) var errorText: String?
    private(set) var isServerReachable = true
    private(set) var isRefreshingStatus = false
    private(set) var lastUploadOutcome: UploadOutcome?
    private(set) var pendingPartialUpload: PartialUpload?
    private(set) var uploadCompletionCount = 0
    // Bumped after each successful playlist action (start/pause/resume) so the
    // view can emit a single haptic per action.
    private(set) var playlistActionCount = 0
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
    private(set) var lastPullDate: Date? {
        didSet {
            persistLastPullDate()
        }
    }
    private(set) var playlistProgress: PlaylistProgress? {
        didSet {
            persistPlaylistProgress()
        }
    }
    private(set) var isUpdatingInterval = false

    private let maxConcurrentUploads = 5
    private let userDefaults: UserDefaults
    private let sharedDefaults: UserDefaults?

    // Last interval value confirmed by the server; guards against echoing a
    // polled value back as an UpdatePlaylistInterval mutation.
    private var serverCronIntervalInHours: Int?

    private var uploadTask: Task<Void, Never>?
    private var playlistStartTask: Task<Void, Never>?
    private var playlistPauseTask: Task<Void, Never>?
    private var playlistIntervalTask: Task<Void, Never>?
    private var quietHoursTask: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.sharedDefaults = CanvasSettings.sharedDefaults
        self.serverURL = CanvasSettings.serverURL
        self.canvasURL = CanvasSettings.deviceURL
        self.quietHoursEnabled = userDefaults.bool(forKey: Self.quietHoursEnabledDefaultsKey)
        self.quietHoursStart = userDefaults.object(forKey: Self.quietHoursStartDefaultsKey) as? Int ?? 23
        self.quietHoursEnd = userDefaults.object(forKey: Self.quietHoursEndDefaultsKey) as? Int ?? 7

        if let cached = userDefaults.object(forKey: CanvasCacheKeys.batteryPercentage) as? Int {
            self.canvasBatteryPercentage = cached
        }
        if let timestamp = userDefaults.object(forKey: CanvasCacheKeys.lastFullChargeDate) as? Double {
            self.lastFullChargeDate = Date(timeIntervalSince1970: timestamp)
        }
        if let timestamp = userDefaults.object(forKey: CanvasCacheKeys.lastPullDate) as? Double {
            self.lastPullDate = Date(timeIntervalSince1970: timestamp)
        }
    }

    func reloadConfigFromSettings() {
        let newServerURL = CanvasSettings.serverURL
        let newCanvasURL = CanvasSettings.deviceURL
        if newServerURL != serverURL {
            serverURL = newServerURL
        }
        if newCanvasURL != canvasURL {
            canvasURL = newCanvasURL
        }
    }

    var isPhotoAccessGranted: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var canStartUpload: Bool {
        isPhotoAccessGranted && selectedAlbumId != nil && !isUploading && !isStartingPlaylist
            && pendingPartialUpload == nil
    }

    var canStartPlaylist: Bool {
        !isUploading && !isStartingPlaylist && !isPausingPlaylist
    }

    var isPlaylistRunning: Bool {
        playlistProgress?.status == .inProgress
    }

    var isPlaylistPaused: Bool {
        playlistProgress?.status == .paused
    }

    /// True when the device missed its scheduled wake-up (with a grace period
    /// for clock drift): likely out of battery or out of Wi-Fi range.
    var isCanvasSilent: Bool {
        guard let nextPullDate = playlistProgress?.nextPullDate else { return false }
        return Date().timeIntervalSince(nextPullDate) > 30 * 60
    }

    /// Absolute URL of the image currently on the Canvas.
    var currentImageURL: URL? {
        guard let path = playlistProgress?.currentImagePath,
              let baseURL = validatedHTTPURL(serverURL) else { return nil }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    var canPausePlaylist: Bool {
        isPlaylistRunning && !isUploading && !isStartingPlaylist && !isPausingPlaylist
    }

    var canResumePlaylist: Bool {
        isPlaylistPaused && !isUploading && !isStartingPlaylist && !isPausingPlaylist
    }

    func clearError() {
        errorText = nil
    }

    func bootstrap() async {
        // Status first: it must not wait for the user to answer the Photos prompt.
        await refreshCanvasBattery()

        authorizationStatus = PhotoLibraryService.authorizationStatus()
        if !isPhotoAccessGranted {
            authorizationStatus = await PhotoLibraryService.requestAuthorization()
        }
        guard isPhotoAccessGranted else { return }
        reloadAlbums()
    }

    func refreshCanvasBattery() async {
        reloadConfigFromSettings()
        guard let baseURL = validatedHTTPURL(serverURL) else {
            isServerReachable = false
            return
        }

        isRefreshingStatus = true
        defer { isRefreshingStatus = false }

        let batteryService = CanvasStatusService(baseURL: baseURL)
        let playlistService = PlaylistService(baseURL: baseURL)

        async let batteryResult = batteryService.getBatteryData()
        async let progressResult = playlistService.getProgress()

        // On transport errors, keep the last known values instead of blanking
        // the UI — a single failed LAN poll must not erase the whole state.
        var reachable = true

        do {
            if let batteryData = try await batteryResult {
                canvasBatteryPercentage = batteryData.percentage

                lastFullChargeDate = batteryData.lastFullChargeDate.flatMap(GraphQLDate.parse)
                lastPullDate = batteryData.lastPullDate.flatMap(GraphQLDate.parse)
            } else {
                // The server answered but has never seen a battery report.
                canvasBatteryPercentage = nil
                lastFullChargeDate = nil
                lastPullDate = nil
            }
        } catch {
            reachable = false
        }

        do {
            let progress = try await progressResult
            playlistProgress = progress
            if let progress {
                serverCronIntervalInHours = progress.cronIntervalInHours
                if playlistIntervalTask == nil {
                    cronIntervalInHours = progress.cronIntervalInHours
                }
                if quietHoursEnabled,
                   userDefaults.string(forKey: Self.quietHoursTimezoneDefaultsKey) != TimeZone.current.identifier {
                    pushQuietHours(silent: true)
                }
            }
        } catch {
            reachable = false
        }

        isServerReachable = reachable

        WidgetCenter.shared.reloadAllTimelines()
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

        playlistStartTask?.cancel()
        playlistStartTask = Task {
            await runPlaylistStart(
                baseURL: url,
                canvasURL: canvasEndpoint,
                cronIntervalInHours: cronIntervalInHours
            )
        }
    }

    func pausePlaylist() {
        errorText = nil

        guard let url = validatedHTTPURL(serverURL) else {
            errorText = AppError.invalidServerURL.localizedDescription
            return
        }

        playlistPauseTask?.cancel()
        playlistPauseTask = Task {
            await runPlaylistPause(baseURL: url)
        }
    }

    func resumePlaylist() {
        errorText = nil

        guard let url = validatedHTTPURL(serverURL) else {
            errorText = AppError.invalidServerURL.localizedDescription
            return
        }

        playlistPauseTask?.cancel()
        playlistPauseTask = Task {
            await runPlaylistResume(baseURL: url)
        }
    }

    func updatePlaylistInterval(_ hours: Int) {
        guard playlistProgress != nil else { return }
        guard hours != serverCronIntervalInHours else { return }
        guard let url = validatedHTTPURL(serverURL) else {
            errorText = AppError.invalidServerURL.localizedDescription
            return
        }

        playlistIntervalTask?.cancel()
        playlistIntervalTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            await runPlaylistUpdateInterval(baseURL: url, hours: hours)
        }
    }

    /// `silent`: background sync (iPhone timezone change) — no toast for it.
    private func pushQuietHours(silent: Bool = false) {
        guard playlistProgress != nil else { return }
        guard let url = validatedHTTPURL(serverURL) else { return }

        quietHoursTask?.cancel()
        quietHoursTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            await runQuietHoursUpdate(baseURL: url, silent: silent)
        }
    }

    private func runQuietHoursUpdate(baseURL: URL, silent: Bool) async {
        defer { quietHoursTask = nil }

        let service = PlaylistService(baseURL: baseURL)
        do {
            let payload = quietHoursPayload()
            let message = try await service.updateQuietHours(payload)
            if !silent { statusText = message }
            markQuietHoursTimezoneSent(payload)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func quietHoursPayload() -> PlaylistService.QuietHoursPayload {
        PlaylistService.QuietHoursPayload(
            enabled: quietHoursEnabled,
            // Quiet hours follow the iPhone's clock, wherever it travels.
            timezone: TimeZone.current.identifier,
            start: quietHoursStart,
            end: quietHoursEnd
        )
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

        let assets = await Self.fetchPhotoAssets(in: albumId)
        guard !assets.isEmpty else {
            errorText = AppError.noPhotosInAlbum.localizedDescription
            return
        }

        statusText = String(localized: "Upload en cours...")
        let uploader = UploadService(baseURL: baseURL)
        let imageService = ImageService(baseURL: baseURL)
        progress = UploadProgress(total: assets.count, processed: 0, uploaded: 0, failed: 0)

        var batch = await uploadBatch(assets, uploader: uploader, isRetry: false)
        var uploadedIDs = batch.uploadedIDs

        // A photo can fail on a transient error (iCloud download, Wi-Fi hiccup):
        // give the failed ones one more chance before asking anything.
        if !batch.isCancelled, !batch.failedAssets.isEmpty {
            statusText = String(localized: "Nouvel essai pour \(batch.failedAssets.count) photos...")
            batch = await uploadBatch(batch.failedAssets, uploader: uploader, isRetry: true)
            uploadedIDs += batch.uploadedIDs
        }

        if batch.isCancelled || Task.isCancelled {
            // Roll back so the old album stays exactly as it was. Apollo calls are
            // not cancellation-aware, so this still runs on a cancelled task.
            if !uploadedIDs.isEmpty {
                try? await imageService.delete(ids: uploadedIDs)
            }
            statusText = String(localized: "Upload annulé.")
            return
        }

        // Nothing reached the server: keep the current album untouched.
        guard !uploadedIDs.isEmpty else {
            statusText = String(localized: "Aucune photo n'a pu être envoyée.")
            lastUploadOutcome = .failure
            uploadCompletionCount += 1
            return
        }

        // Some photos are still missing: replacing the album with a subset is
        // the user's call, not a silent default.
        if !batch.failedAssets.isEmpty {
            pendingPartialUpload = PartialUpload(
                uploadedIDs: uploadedIDs,
                failedCount: batch.failedAssets.count,
                baseURL: baseURL
            )
            statusText = String(localized: "\(batch.failedAssets.count) photos n'ont pas pu être envoyées.")
            return
        }

        await replaceAlbum(keeping: uploadedIDs, baseURL: baseURL)
    }

    /// Photos uploaded while others kept failing, waiting for the user to
    /// replace the album with them or to roll them back.
    struct PartialUpload {
        let uploadedIDs: [String]
        let failedCount: Int
        let baseURL: URL

        var uploadedCount: Int { uploadedIDs.count }
    }

    func confirmPartialUpload() {
        guard let pending = pendingPartialUpload else { return }
        pendingPartialUpload = nil
        uploadTask = Task {
            isUploading = true
            defer {
                isUploading = false
                uploadTask = nil
            }
            await replaceAlbum(keeping: pending.uploadedIDs, baseURL: pending.baseURL)
        }
    }

    func cancelPartialUpload() {
        guard let pending = pendingPartialUpload else { return }
        pendingPartialUpload = nil
        Task {
            try? await ImageService(baseURL: pending.baseURL).delete(ids: pending.uploadedIDs)
            statusText = String(localized: "Upload annulé.")
        }
    }

    /// The old album stayed on the Canvas during the upload; it is only
    /// replaced once the new photos are on the server.
    private func replaceAlbum(keeping uploadedIDs: [String], baseURL: URL) async {
        statusText = String(localized: "Suppression des photos serveur...")
        do {
            try await ImageService(baseURL: baseURL).keepOnly(ids: uploadedIDs)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastUploadOutcome = .failure
            uploadCompletionCount += 1
            return
        }

        statusText = String(localized: "Terminé : \(uploadedIDs.count) photos envoyées.")
        lastUploadOutcome = progress.failed > 0 ? .failure : .success
        uploadCompletionCount += 1
    }

    private struct BatchResult {
        var uploadedIDs: [String] = []
        var failedAssets: [PHAsset] = []
        var isCancelled = false
    }

    /// Uploads `assets` with at most `maxConcurrentUploads` in flight. On a
    /// retry, the photos were already counted as processed and failed: a
    /// success only moves one from failed to uploaded.
    private func uploadBatch(_ assets: [PHAsset], uploader: UploadService, isRetry: Bool) async -> BatchResult {
        var result = BatchResult()
        var nextAssetIndex = 0

        await withTaskGroup(of: (Int, UploadItemResult).self) { group in
            func enqueueNext() {
                guard nextAssetIndex < assets.count else { return }
                let index = nextAssetIndex
                let asset = assets[index]
                nextAssetIndex += 1
                group.addTask {
                    (index, await AppViewModel.uploadAsset(asset, uploader: uploader))
                }
            }

            for _ in 0 ..< min(maxConcurrentUploads, assets.count) {
                enqueueNext()
            }

            while let (index, itemResult) = await group.next() {
                if Task.isCancelled {
                    group.cancelAll()
                    result.isCancelled = true
                    return
                }

                switch itemResult {
                case let .uploaded(id):
                    result.uploadedIDs.append(id)
                    progress.uploaded += 1
                    if isRetry { progress.failed -= 1 }
                case .failed:
                    result.failedAssets.append(assets[index])
                    if !isRetry { progress.failed += 1 }
                case .cancelled:
                    result.isCancelled = true
                }

                if !isRetry {
                    progress.processed += 1
                    statusText = String(localized: "Upload \(progress.processed)/\(progress.total)")
                }

                enqueueNext()
            }
        }

        return result
    }

    @concurrent
    private nonisolated static func fetchPhotoAssets(in albumId: String) async -> [PHAsset] {
        PhotoLibraryService.fetchPhotoAssets(in: albumId)
    }

    private nonisolated enum UploadItemResult: Sendable {
        case uploaded(id: String)
        case failed
        case cancelled
    }

    /// `@concurrent`: each photo is fetched, rendered and sent on the global
    /// executor, so the five uploads really run in parallel and the main
    /// thread only handles the progress updates.
    @concurrent
    private nonisolated static func uploadAsset(_ asset: PHAsset, uploader: UploadService) async -> UploadItemResult {
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

            let id = try await uploader.uploadJPEG(
                processedImage.jpegData,
                orientation: processedImage.orientation.rawValue
            )
            return .uploaded(id: id)
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
            let quietHours = quietHoursEnabled ? quietHoursPayload() : nil
            let result = try await service.start(
                canvasURL: canvasURL,
                cronIntervalInHours: cronIntervalInHours,
                quietHours: quietHours
            )
            markQuietHoursTimezoneSent(quietHours)
            statusText = result.message
            playlistActionCount += 1
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        await refreshCanvasBattery()
    }

    private func runPlaylistPause(baseURL: URL) async {
        isPausingPlaylist = true
        statusText = String(localized: "Mise en pause...")
        errorText = nil

        defer {
            isPausingPlaylist = false
            playlistPauseTask = nil
        }

        let service = PlaylistService(baseURL: baseURL)
        do {
            statusText = try await service.pause()
            playlistActionCount += 1
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        await refreshCanvasBattery()
    }

    private func runPlaylistResume(baseURL: URL) async {
        isPausingPlaylist = true
        statusText = String(localized: "Reprise...")
        errorText = nil

        defer {
            isPausingPlaylist = false
            playlistPauseTask = nil
        }

        let service = PlaylistService(baseURL: baseURL)
        do {
            let result = try await service.resume()
            statusText = result.message
            playlistActionCount += 1
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        await refreshCanvasBattery()
    }

    private func runPlaylistUpdateInterval(baseURL: URL, hours: Int) async {
        isUpdatingInterval = true
        defer {
            isUpdatingInterval = false
            playlistIntervalTask = nil
        }

        let service = PlaylistService(baseURL: baseURL)
        do {
            statusText = try await service.updateInterval(cronIntervalInHours: hours)
            serverCronIntervalInHours = hours
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func validatedHTTPURL(_ rawValue: String) -> URL? {
        CanvasSettings.validatedHTTPURL(rawValue)
    }

    private func persistCanvasBatteryPercentage() {
        guard let canvasBatteryPercentage else {
            userDefaults.removeObject(forKey: CanvasCacheKeys.batteryPercentage)
            sharedDefaults?.removeObject(forKey: CanvasCacheKeys.batteryPercentage)
            return
        }
        userDefaults.set(canvasBatteryPercentage, forKey: CanvasCacheKeys.batteryPercentage)
        sharedDefaults?.set(canvasBatteryPercentage, forKey: CanvasCacheKeys.batteryPercentage)
    }

    private func persistLastFullChargeDate() {
        guard let lastFullChargeDate else {
            userDefaults.removeObject(forKey: CanvasCacheKeys.lastFullChargeDate)
            sharedDefaults?.removeObject(forKey: CanvasCacheKeys.lastFullChargeDate)
            return
        }
        let timestamp = lastFullChargeDate.timeIntervalSince1970
        userDefaults.set(timestamp, forKey: CanvasCacheKeys.lastFullChargeDate)
        sharedDefaults?.set(timestamp, forKey: CanvasCacheKeys.lastFullChargeDate)
    }

    private func persistLastPullDate() {
        guard let lastPullDate else {
            userDefaults.removeObject(forKey: CanvasCacheKeys.lastPullDate)
            sharedDefaults?.removeObject(forKey: CanvasCacheKeys.lastPullDate)
            return
        }
        let timestamp = lastPullDate.timeIntervalSince1970
        userDefaults.set(timestamp, forKey: CanvasCacheKeys.lastPullDate)
        sharedDefaults?.set(timestamp, forKey: CanvasCacheKeys.lastPullDate)
    }

    private func persistPlaylistProgress() {
        guard let progress = playlistProgress else {
            sharedDefaults?.removeObject(forKey: CanvasCacheKeys.playlistDisplayed)
            sharedDefaults?.removeObject(forKey: CanvasCacheKeys.playlistTotal)
            sharedDefaults?.removeObject(forKey: CanvasCacheKeys.nextPullDate)
            return
        }
        sharedDefaults?.set(progress.displayed, forKey: CanvasCacheKeys.playlistDisplayed)
        sharedDefaults?.set(progress.total, forKey: CanvasCacheKeys.playlistTotal)
        // The widget flags a silent Canvas from this date, even before its own fetch.
        sharedDefaults?.set(progress.nextPullDate?.timeIntervalSince1970, forKey: CanvasCacheKeys.nextPullDate)
    }

    private func persistQuietHoursEnabled() {
        userDefaults.set(quietHoursEnabled, forKey: Self.quietHoursEnabledDefaultsKey)
    }

    private func markQuietHoursTimezoneSent(_ payload: PlaylistService.QuietHoursPayload?) {
        guard let payload else { return }
        userDefaults.set(payload.timezone, forKey: Self.quietHoursTimezoneDefaultsKey)
    }
}
