import Foundation

struct PhotoAlbum: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let photoCount: Int
}

struct UploadProgress: Sendable {
    var total: Int
    var processed: Int
    var uploaded: Int
    var failed: Int

    static let empty = UploadProgress(total: 0, processed: 0, uploaded: 0, failed: 0)

    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return Double(processed) / Double(total)
    }
}

enum AppError: LocalizedError {
    case invalidServerURL
    case missingAlbumSelection
    case resizeFailed
    case noPhotosInAlbum

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return String(localized: "URL serveur invalide.")
        case .missingAlbumSelection:
            return String(localized: "Sélectionnez un album.")
        case .resizeFailed:
            return String(localized: "Impossible de convertir l'image en JPEG 1200×1600.")
        case .noPhotosInAlbum:
            return String(localized: "Cet album ne contient pas de photos.")
        }
    }
}
