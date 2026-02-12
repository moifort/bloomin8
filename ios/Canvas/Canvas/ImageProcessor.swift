import UIKit

enum UploadOrientation: String {
    case portrait = "P"
    case landscape = "L"
}

struct ProcessedImage {
    let jpegData: Data
    let orientation: UploadOrientation
}

enum ImageProcessor {
    static let targetSize = CGSize(width: 1200, height: 1600)

    static func processForUpload(
        _ image: UIImage,
        compressionQuality: CGFloat = 0.88
    ) -> ProcessedImage? {
        guard image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let normalizedImage = normalizeOrientation(image)
        let orientation: UploadOrientation =
            normalizedImage.size.width > normalizedImage.size.height ? .landscape : .portrait
        
        // Pour les images paysage, on les crop au centre en mode portrait
        // au lieu de les faire pivoter
        let imageForRendering =
            orientation == .landscape ? centerCropToPortrait(normalizedImage) : normalizedImage

        guard let jpegData = renderAspectFillJPEG(
            imageForRendering,
            compressionQuality: compressionQuality
        ) else {
            return nil
        }

        return ProcessedImage(jpegData: jpegData, orientation: orientation)
    }

    private static func renderAspectFillJPEG(
        _ image: UIImage,
        compressionQuality: CGFloat
    ) -> Data? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return nil
        }

        let horizontalScale = targetSize.width / sourceSize.width
        let verticalScale = targetSize.height / sourceSize.height
        let fillScale = max(horizontalScale, verticalScale)

        let scaledSize = CGSize(
            width: sourceSize.width * fillScale,
            height: sourceSize.height * fillScale
        )

        let drawRect = CGRect(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let output = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: drawRect)
        }

        return output.jpegData(compressionQuality: compressionQuality)
    }

    private static func normalizeOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(size: image.size, format: rendererFormat)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func centerCropToPortrait(_ image: UIImage) -> UIImage {
        // L'image est en mode paysage (largeur > hauteur)
        // On veut la cropper au centre pour obtenir un format portrait
        
        let sourceSize = image.size
        let targetAspectRatio = targetSize.width / targetSize.height // 1200/1600 = 0.75
        
        // Calculer la nouvelle largeur pour obtenir le bon ratio portrait
        let croppedWidth = sourceSize.height * targetAspectRatio
        
        // Centrer le crop horizontalement
        let cropX = (sourceSize.width - croppedWidth) / 2
        let cropRect = CGRect(
            x: cropX,
            y: 0,
            width: croppedWidth,
            height: sourceSize.height
        )
        
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        rendererFormat.opaque = true
        
        let croppedSize = CGSize(width: croppedWidth, height: sourceSize.height)
        let renderer = UIGraphicsImageRenderer(size: croppedSize, format: rendererFormat)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Dessiner seulement la partie croppée de l'image
            if let cgImage = image.cgImage?.cropping(to: cropRect) {
                let croppedImage = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
                croppedImage.draw(in: CGRect(origin: .zero, size: croppedSize))
            } else {
                // Fallback: dessiner l'image complète avec un offset
                cgContext.translateBy(x: -cropX, y: 0)
                image.draw(in: CGRect(origin: .zero, size: sourceSize))
            }
        }
    }
}
