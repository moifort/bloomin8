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

    /// Aspect-fills the photo into the portrait panel: landscape photos are
    /// center-cropped, so the stored pixels are always portrait. They must
    /// therefore be sent as `_P` — `_L` tells the device to rotate them 90°.
    static func processForUpload(
        _ image: UIImage,
        compressionQuality: CGFloat = 0.88
    ) -> ProcessedImage? {
        guard let jpegData = renderAspectFillJPEG(image, compressionQuality: compressionQuality) else {
            return nil
        }
        return ProcessedImage(jpegData: jpegData, orientation: .portrait)
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
}
