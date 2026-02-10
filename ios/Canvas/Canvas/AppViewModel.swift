import Foundation
import Combine
import Photos

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = PhotoLibraryService.authorizationStatus()
    @Published private(set) var albums: [PhotoAlbum] = []
    @Published var selectedAlbumId: String?
    @Published var serverURL: String = "http://192.168.0.165:3000"

    @Published private(set) var isUploading = false
    @Published private(set) var isStartingPlaylist = false
    @Published private(set) var progress = UploadProgress.empty
    @Published private(set) var statusText: String = ""
    @Published private(set) var errorText: String?

    private var uploadTask: Task<Void, Never>?
    private var playlistStartTask: Task<Void, Never>?

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
        guard isPhotoAccessGranted else { return }
        reloadAlbums()
    }

    func requestPhotoAccess() {
        Task {
            authorizationStatus = await PhotoLibraryService.requestAuthorization()
            guard isPhotoAccessGranted else {
                errorText = "Acces Photos refuse."
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

        playlistStartTask?.cancel()
        playlistStartTask = Task {
            await runPlaylistStart(baseURL: url)
        }
    }

    private func runUpload(albumId: String, baseURL: URL) async {
        isUploading = true
        progress = .empty
        statusText = "Lecture de l'album..."
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

        let uploader = UploadService(baseURL: baseURL)
        progress = UploadProgress(total: assets.count, processed: 0, uploaded: 0, failed: 0)

        for asset in assets {
            if Task.isCancelled {
                statusText = "Upload annule."
                return
            }

            do {
                let sourceImage = try await PhotoLibraryService.requestUIImage(for: asset)
                guard let processedImage = ImageProcessor.processForUpload(sourceImage) else {
                    throw AppError.resizeFailed
                }

                _ = try await uploader.uploadJPEG(
                    processedImage.jpegData,
                    orientation: processedImage.orientation.rawValue
                )
                progress.uploaded += 1
            } catch {
                progress.failed += 1
            }

            progress.processed += 1
            statusText = "Upload \(progress.processed)/\(progress.total)"
        }

        statusText = "Termine: \(progress.uploaded) envoyees, \(progress.failed) echecs."
    }

    private func runPlaylistStart(baseURL: URL) async {
        isStartingPlaylist = true
        statusText = "Lancement de la playlist..."
        errorText = nil

        defer {
            isStartingPlaylist = false
            playlistStartTask = nil
        }

        let service = PlaylistService(baseURL: baseURL)
        do {
            statusText = try await service.start()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func validatedHTTPURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }

        return url
    }
}
