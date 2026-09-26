import UIKit

enum SomaImage {
    static func jpeg(from image: UIImage, maxDimension: CGFloat = 1_024, quality: CGFloat = 0.82) -> Data? {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: quality)
        }

        let scale = maxDimension / longestSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
