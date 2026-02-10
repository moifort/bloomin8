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
        let imageForRendering =
            orientation == .landscape ? rotateClockwise(normalizedImage) : normalizedImage

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

    private static func rotateClockwise(_ image: UIImage) -> UIImage {
        let rotatedSize = CGSize(width: image.size.height, height: image.size.width)
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(size: rotatedSize, format: rendererFormat)
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            cgContext.rotate(by: .pi / 2)

            let drawRect = CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: drawRect)
        }
    }
}
