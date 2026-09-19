//
//  SomaImage.swift
//  SomaTracker
//
//  Photo preparation shared by every surface that sends a plate to an engine.
//

import UIKit

enum SomaImage {
    /// Gemini does not need a 12 MP plate. Shrinking to 1024 px keeps the base64 payload (built on the
    /// main actor) roughly ten times smaller, and both engines read it just as well.
    static func jpeg(from image: UIImage, maxDimension: CGFloat = 1_024, quality: CGFloat = 0.82) -> Data? {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: quality)
        }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
