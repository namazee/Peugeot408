import CarKit
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Builds the My Car PNG from a built-in photo: optional paint colour, optional plate text.
enum CarPhotoRenderer {
    private static let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])

    /// PNG for a built-in photo that is already cut out.
    static func render(_ photo: BuiltInCarPhoto, paintHex: UInt32?, plate: String, font: PlateFont) -> Data? {
        processed(photo, paintHex: paintHex, plate: plate, font: font).flatMap { UIImage(cgImage: $0).pngData() }
    }

    /// The full-size photo with paint colour and plate applied (background still there for studio renders).
    static func processed(_ photo: BuiltInCarPhoto, paintHex: UInt32?, plate: String, font: PlateFont) -> CGImage? {
        guard let url = photo.url, let base = CIImage(contentsOf: url) else { return nil }
        var image = base

        if let paintHex {
            let dimension = 32
            let cube = PaintRecolor.cube(dimension: dimension, target: paintHex)
            let filter = CIFilter.colorCubeWithColorSpace()
            filter.inputImage = image
            filter.cubeDimension = Float(dimension)
            filter.cubeData = cube.withUnsafeBufferPointer { Data(buffer: $0) }
            filter.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            if let recoloured = filter.outputImage {
                // Keep windows and the plate as they were (white in the mask = original).
                if let keep = keepMask(for: photo, size: base.extent.size) {
                    let blend = CIFilter.blendWithMask()
                    blend.inputImage = base
                    blend.backgroundImage = recoloured
                    blend.maskImage = keep
                    image = blend.outputImage ?? recoloured
                } else {
                    image = recoloured
                }
            }
        }

        let text = plate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !text.isEmpty, let quad = photo.plateQuad?.expanded(by: 2),
           let plateImage = plateImage(text, aspect: quad.aspect, font: font, brightness: plateBrightness(base, quad: quad)) {
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
                // A touch of blur so the plate is as sharp as the photo around it, not crisper.
                let soft = warped.clampedToExtent().applyingGaussianBlur(sigma: 0.6).cropped(to: warped.extent)
                image = soft.composited(over: image)
            }
        }

        return context.createCGImage(image, from: base.extent)
    }

    /// White where the photo must stay as it is: the windows and the plate.
    static func keepMask(for photo: BuiltInCarPhoto, size: CGSize) -> CIImage? {
        let shapes = photo.glass + (photo.plateQuad.map { quad in
            [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft].map { (Double($0.x), Double($0.y)) }
        }.map { [$0] } ?? [])
        guard !shapes.isEmpty else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            for shape in shapes where shape.count >= 3 {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: shape[0].0, y: shape[0].1))
                for point in shape.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
                path.close()
                path.fill()
            }
        }
        guard let cg = image.cgImage else { return nil }
        // Soft edge so there's no hard line between painted body and glass.
        let mask = CIImage(cgImage: cg)
        return mask.clampedToExtent().applyingGaussianBlur(sigma: 2).cropped(to: mask.extent)
    }

    /// How bright the plate should be: follows the light on the original plate
    /// (a sunlit show plate ≈ 1, a plate in a dark studio ≈ 0.45).
    static func plateBrightness(_ image: CIImage, quad: PlateQuad) -> Double {
        let xs = [quad.topLeft.x, quad.topRight.x, quad.bottomRight.x, quad.bottomLeft.x]
        let ys = [quad.topLeft.y, quad.topRight.y, quad.bottomRight.y, quad.bottomLeft.y]
        let height = image.extent.height
        let rect = CGRect(x: xs.min() ?? 0, y: height - (ys.max() ?? 0), width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
        let average = CIFilter.areaAverage()
        average.inputImage = image
        average.extent = rect
        guard let output = average.outputImage else { return 1 }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        let luminance = (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
        return min(max(luminance / 0.7, 0.45), 1)
    }

    /// A Malaysian-style plate: black, thin edge, raised white characters, slight gloss, lit like the photo.
    static func plateImage(_ text: String, aspect: Double, font: PlateFont, brightness: Double = 1) -> CIImage? {
        let height = 120.0
        let width = height * min(max(aspect, 1.5), 6)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            let b = CGFloat(brightness)
            UIColor(white: 0.06, alpha: 1).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: height * 0.08).fill()
            // Gloss: a faint light band across the top half.
            let gloss = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [UIColor(white: 1, alpha: 0.10 * b).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray,
                                   locations: [0, 1])
            if let gloss {
                context.cgContext.saveGState()
                UIBezierPath(roundedRect: rect, cornerRadius: height * 0.08).addClip()
                context.cgContext.drawLinearGradient(gloss, start: .zero, end: CGPoint(x: 0, y: height * 0.55), options: [])
                context.cgContext.restoreGState()
            }
            UIColor(white: 0.55 * b, alpha: 1).setStroke()
            let edge = UIBezierPath(roundedRect: rect.insetBy(dx: 2.5, dy: 2.5), cornerRadius: height * 0.07)
            edge.lineWidth = 2.5
            edge.stroke()

            // Fit the text: start large and shrink until it fits with a margin.
            var size = height * 0.72
            var attributes: [NSAttributedString.Key: Any] = [:]
            var textSize = CGSize.zero
            repeat {
                attributes = [.font: uiFont(font, size: size), .foregroundColor: UIColor(white: 0.93 * b, alpha: 1)]
                textSize = (text as NSString).size(withAttributes: attributes)
                size -= 2
            } while textSize.width > width * 0.88 && size > 10
            let origin = CGPoint(x: (width - textSize.width) / 2, y: (height - textSize.height) / 2)
            // Raised characters: a dark shadow just below, then the face.
            var shadowed = attributes
            shadowed[.foregroundColor] = UIColor(white: 0, alpha: 0.85)
            (text as NSString).draw(at: CGPoint(x: origin.x + 1.5, y: origin.y + 2), withAttributes: shadowed)
            (text as NSString).draw(at: origin, withAttributes: attributes)
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
