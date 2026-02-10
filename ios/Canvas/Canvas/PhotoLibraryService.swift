import Foundation
import Photos
import UIKit

enum PhotoLibraryService {
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
            options.resizeMode = .none
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) {
                data,
                _,
                _,
                info in
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: FetchImageError.cancelled)
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: FetchImageError.underlying(error))
                    return
                }

                guard let data, let image = UIImage(data: data) else {
                    continuation.resume(throwing: FetchImageError.invalidData)
                    return
                }

                continuation.resume(returning: image)
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
