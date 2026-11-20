import CarKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Builds the My Car PNG from a built-in photo: optional paint colour, optional plate text.
enum CarPhotoRenderer {
    private static let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])

    static func render(_ photo: BuiltInCarPhoto, paintHex: UInt32?, plate: String, font: PlateFont) -> Data? {
        guard let url = Bundle.main.url(forResource: photo.resource, withExtension: "png"),
              let base = CIImage(contentsOf: url) else { return nil }
        var image = base

        if let paintHex {
            let dimension = 32
            let cube = PaintRecolor.cube(dimension: dimension, target: paintHex)
            let filter = CIFilter.colorCubeWithColorSpace()
            filter.inputImage = image
            filter.cubeDimension = Float(dimension)
            filter.cubeData = cube.withUnsafeBufferPointer { Data(buffer: $0) }
            filter.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            if let output = filter.outputImage { image = output }
        }

        let text = plate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !text.isEmpty, let quad = photo.plateQuad?.expanded(by: 2), let plateImage = plateImage(text, aspect: quad.aspect, font: font) {
            // Core Image's origin is bottom-left; the measured corners are top-left based.
            let height = base.extent.height
            func ci(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: height - p.y) }
            let warp = CIFilter.perspectiveTransform()
            warp.inputImage = plateImage
            warp.topLeft = ci(quad.topLeft)
            warp.topRight = ci(quad.topRight)
            warp.bottomRight = ci(quad.bottomRight)
            warp.bottomLeft = ci(quad.bottomLeft)
            if let warped = warp.outputImage {
                image = warped.composited(over: image)
            }
        }

        guard let cgImage = context.createCGImage(image, from: base.extent) else { return nil }
        return UIImage(cgImage: cgImage).pngData()
    }

    /// A Malaysian-style plate: black, thin light edge, white characters.
    static func plateImage(_ text: String, aspect: Double, font: PlateFont) -> CIImage? {
        let height = 120.0
        let width = height * min(max(aspect, 1.5), 6)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            UIColor.black.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: height * 0.08).fill()
            UIColor(white: 0.85, alpha: 1).setStroke()
            let edge = UIBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: height * 0.07)
            edge.lineWidth = 3
            edge.stroke()

            // Fit the text: start large and shrink until it fits with a margin.
            var size = height * 0.72
            var attributes: [NSAttributedString.Key: Any] = [:]
            var textSize = CGSize.zero
            repeat {
                attributes = [.font: uiFont(font, size: size), .foregroundColor: UIColor.white]
                textSize = (text as NSString).size(withAttributes: attributes)
                size -= 2
            } while textSize.width > width * 0.88 && size > 10
            let origin = CGPoint(x: (width - textSize.width) / 2, y: (height - textSize.height) / 2)
            (text as NSString).draw(at: origin, withAttributes: attributes)
            _ = context
        }
        return image.cgImage.map { CIImage(cgImage: $0) }
    }

    static func uiFont(_ font: PlateFont, size: CGFloat) -> UIFont {
        switch font {
        case .classic:
            return .systemFont(ofSize: size, weight: .heavy)
        case .condensed:
            return .systemFont(ofSize: size, weight: .bold, width: .condensed)
        case .mono:
            return .monospacedSystemFont(ofSize: size, weight: .bold)
        case .rounded:
            let base = UIFont.systemFont(ofSize: size, weight: .heavy)
            return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        case .orbitron:
            return variable("Orbitron-Regular", weight: 800, size: size) ?? .systemFont(ofSize: size, weight: .heavy)
        case .rajdhani:
            return UIFont(name: "Rajdhani-Bold", size: size) ?? .systemFont(ofSize: size, weight: .bold)
        }
    }

    /// Bundled variable font at a given weight (the `wght` axis).
    private static func variable(_ name: String, weight: Double, size: CGFloat) -> UIFont? {
        guard let font = UIFont(name: name, size: size) else { return nil }
        let wghtTag = 0x7767_6874 // "wght"
        let descriptor = font.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtTag: weight],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}
