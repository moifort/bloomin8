import UIKit

enum UploadOrientation: String, Sendable {
    case portrait = "P"
    case landscape = "L"
}

struct ProcessedImage: Sendable {
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
        rendererFormat.preferredRange = .standard

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
        rendererFormat.preferredRange = .standard

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
        
        guard let cgImage = image.cgImage else {
            return image
        }
        
        // Convertir en coordonnées de pixel
        let scale = cgImage.width / Int(sourceSize.width)
        let pixelCropRect = CGRect(
            x: cropX * CGFloat(scale),
            y: 0,
            width: croppedWidth * CGFloat(scale),
            height: sourceSize.height * CGFloat(scale)
        ).integral
        
        guard let croppedCGImage = cgImage.cropping(to: pixelCropRect) else {
            return image
        }
        
        return UIImage(cgImage: croppedCGImage, scale: 1, orientation: .up)
    }
}
