import Foundation
import Photos
import UIKit

/// PhotoKit fetches and image requests are thread-safe and can be slow on big
/// libraries: nothing here is tied to the main actor.
nonisolated enum PhotoLibraryService {
    enum FetchImageError: LocalizedError {
        case cancelled
        case invalidData
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return String(localized: "Chargement annulé.")
            case .invalidData:
                return String(localized: "Données image invalides.")
            case let .underlying(error):
                return error.localizedDescription
            }
        }
    }

    static func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// User albums first, then smart albums, each sorted by title. Counting
    /// the photos of every album is slow on a big library: never call this
    /// from the main actor.
    static func fetchAlbums() -> [PhotoAlbum] {
        albums(of: .album, kind: .user) + albums(of: .smartAlbum, kind: .smart)
    }

    private static func albums(of type: PHAssetCollectionType, kind: PhotoAlbum.Kind) -> [PhotoAlbum] {
        let collections = PHAssetCollection.fetchAssetCollections(with: type, subtype: .any, options: nil)
        var output: [PhotoAlbum] = []
        output.reserveCapacity(collections.count)

        collections.enumerateObjects { collection, _, _ in
            let photoCount = fetchPhotoCount(in: collection)
            guard photoCount > 0 else { return }

            let title = collection.localizedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            output.append(PhotoAlbum(
                id: collection.localIdentifier,
                title: (title?.isEmpty == false ? title : nil) ?? String(localized: "Album sans nom"),
                photoCount: photoCount,
                kind: kind
            ))
        }

        return output.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func fetchPhotoAssets(in albumId: String) -> [PHAsset] {
        let collectionFetch = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumId],
            options: nil
        )

        guard let collection = collectionFetch.firstObject else {
            return []
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(in: collection, options: options)
        var output: [PHAsset] = []
        output.reserveCapacity(assets.count)
        assets.enumerateObjects { asset, _, _ in
            output.append(asset)
        }
        return output
    }

    static func requestUIImage(for asset: PHAsset) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            let lock = NSLock()
            var hasResumed = false
            let resumeOnce: (Result<UIImage, Error>) -> Void = { result in
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            PHImageManager.default().requestImage(
                for: asset,
                // aspectFill guarantees both sides cover the panel: a landscape
                // photo comes back 1600 px tall, so the center crop never upscales.
                targetSize: ImageProcessor.targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    resumeOnce(.failure(FetchImageError.cancelled))
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    resumeOnce(.failure(FetchImageError.underlying(error)))
                    return
                }

                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded {
                    return
                }

                guard let image else {
                    resumeOnce(.failure(FetchImageError.invalidData))
                    return
                }

                resumeOnce(.success(image))
            }
        }
    }

    private static func fetchPhotoCount(in collection: PHAssetCollection) -> Int {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(in: collection, options: options).count
    }
}

/// Calls `onChange` whenever the photo library changes (albums added, photos
/// synced from iCloud…), on PhotoKit's background queue.
nonisolated final class PhotoLibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver, Sendable {
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange()
    }
}
