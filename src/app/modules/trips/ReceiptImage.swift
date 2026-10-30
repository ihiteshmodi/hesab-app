import UIKit

/// Shrinks a receipt photo so the database stays small while small print stays readable.
enum ReceiptImage {
    static let longestEdge: CGFloat = 2400
    static let quality: CGFloat = 0.8

    static func compressed(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, longestEdge / longest)
        guard scale < 1 else { return image.jpegData(compressionQuality: quality) }
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
