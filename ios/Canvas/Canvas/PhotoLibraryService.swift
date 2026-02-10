import Foundation
import Photos
import UIKit

enum PhotoLibraryService {
    private static func uploadFetchTargetSize(for asset: PHAsset) -> CGSize {
        let isLandscape = asset.pixelWidth > asset.pixelHeight
        return isLandscape
            ? CGSize(width: 1600, height: 1200)
            : CGSize(width: 1200, height: 1600)
    }

    enum FetchImageError: LocalizedError {
        case cancelled
        case invalidData
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Chargement annule."
            case .invalidData:
                return "Donnees image invalides."
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

    static func fetchAlbums() -> [PhotoAlbum] {
        let collections = collectAlbumCollections()
        var seen = Set<String>()

        return collections.compactMap { collection in
            guard !seen.contains(collection.localIdentifier) else {
                return nil
            }

            let photoCount = fetchPhotoCount(in: collection)
            guard photoCount > 0 else {
                return nil
            }

            seen.insert(collection.localIdentifier)
            let title = collection.localizedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = "Album sans nom"

            return PhotoAlbum(
                id: collection.localIdentifier,
                title: (title?.isEmpty == false ? title : nil) ?? fallback,
                photoCount: photoCount
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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
                targetSize: uploadFetchTargetSize(for: asset),
                contentMode: .aspectFit,
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

    private static func collectAlbumCollections() -> [PHAssetCollection] {
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

        var output: [PHAssetCollection] = []
        output.reserveCapacity(userAlbums.count + smartAlbums.count)

        userAlbums.enumerateObjects { collection, _, _ in
            output.append(collection)
        }

        smartAlbums.enumerateObjects { collection, _, _ in
            output.append(collection)
        }

        return output
    }
}
