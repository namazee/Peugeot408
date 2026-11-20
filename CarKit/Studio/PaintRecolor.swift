import CoreGraphics
import Foundation

/// Repaints the blue body paint of the built-in My Car photos (spec §4b).
///
/// Every pixel gets a "paint weight" from its hue and saturation: the 408's blue paint
/// (hue about 185–230°, clearly saturated) counts fully, while black trim, glass, grey plates,
/// red lights and green tree reflections count as nothing. Paint pixels take the target colour,
/// scaled by how light or dark they were, so shading and highlights survive. The mapping is baked
/// into a Core Image colour cube, so applying it is one GPU pass.
public enum PaintRecolor {
    public struct Preset: Sendable, Identifiable, Equatable {
        public let id: String
        public let name: String
        /// Nil = the original Obsession Blue (no recolouring).
        public let hex: UInt32?
    }

    /// The 408's Malaysian colours.
    public static let presets: [Preset] = [
        Preset(id: "obsession-blue", name: "Obsession Blue", hex: nil),
        Preset(id: "elixir-red", name: "Elixir Red", hex: 0x8E1A22),
        Preset(id: "okenite-white", name: "Okenite White", hex: 0xE6E6E2),
        Preset(id: "selenium-grey", name: "Selenium Grey", hex: 0x5B5E63),
        Preset(id: "perla-nera-black", name: "Perla Nera Black", hex: 0x16171A),
    ]

    /// Body paint in the photos sits at hue ~196–232°; the cyan light glows are ~185–192°.
    static let hueRange: ClosedRange<Double> = 196...235
    static let hueFeather = 5.0
    /// Typical luminance of the body paint in the photos; pixels lighter than this are highlights.
    static let referenceLuminance = 0.36

    /// 0…1: how much a colour belongs to the body paint.
    public static func weight(r: Double, g: Double, b: Double) -> Double {
        let (h, s, v) = hsv(r: r, g: g, b: b)
        guard v > 0.06 else { return 0 }
        let hueWeight: Double
        if hueRange.contains(h) {
            hueWeight = 1
        } else {
            let distance = h < hueRange.lowerBound ? hueRange.lowerBound - h : h - hueRange.upperBound
            hueWeight = max(0, 1 - distance / hueFeather)
        }
        // Paint is strongly saturated; glass reflections and grey trim are not.
        let satWeight = min(max((s - 0.35) / 0.2, 0), 1)
        let darkWeight = min(max((v - 0.06) / 0.08, 0), 1)
        return hueWeight * satWeight * darkWeight
    }

    /// The recoloured value of one sRGB colour (components 0…1).
    public static func map(r: Double, g: Double, b: Double, target: UInt32) -> (r: Double, g: Double, b: Double) {
        let w = weight(r: r, g: g, b: b)
        guard w > 0 else { return (r, g, b) }
        let t = ColorMath.components(target)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let ratio = luminance / referenceLuminance
        func channel(_ c: Double) -> Double {
            if ratio <= 1 { return c * ratio }
            // Highlights: blend toward white as the original gets brighter.
            let k = min((ratio - 1) / (1 / referenceLuminance - 1), 1)
            return c + (1 - c) * k
        }
        let painted = (channel(t.r), channel(t.g), channel(t.b))
        return (
            min(max(r * (1 - w) + painted.0 * w, 0), 1),
            min(max(g * (1 - w) + painted.1 * w, 0), 1),
            min(max(b * (1 - w) + painted.2 * w, 0), 1)
        )
    }

    /// RGBA float data for `CIColorCubeWithColorSpace` (red changes fastest, then green, then blue).
    public static func cube(dimension: Int = 32, target: UInt32) -> [Float] {
        var data = [Float]()
        data.reserveCapacity(dimension * dimension * dimension * 4)
        let step = 1 / Double(dimension - 1)
        for bi in 0..<dimension {
            for gi in 0..<dimension {
                for ri in 0..<dimension {
                    let out = map(r: Double(ri) * step, g: Double(gi) * step, b: Double(bi) * step, target: target)
                    data += [Float(out.r), Float(out.g), Float(out.b), 1]
                }
            }
        }
        return data
    }

    static func hsv(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        var h = 0.0
        if delta > 0 {
            if maxC == r { h = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == g { h = 60 * ((b - r) / delta + 2) }
            else { h = 60 * ((r - g) / delta + 4) }
        }
        if h < 0 { h += 360 }
        return (h, maxC == 0 ? 0 : delta / maxC, maxC)
    }
}

/// Where the white "408" show plate sits in a built-in photo: four corners in image pixels
/// (top-left origin), measured from the photo.
public struct PlateQuad: Sendable, Equatable {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomRight: CGPoint
    public let bottomLeft: CGPoint

    public init(_ tl: (Double, Double), _ tr: (Double, Double), _ br: (Double, Double), _ bl: (Double, Double)) {
        topLeft = CGPoint(x: tl.0, y: tl.1)
        topRight = CGPoint(x: tr.0, y: tr.1)
        bottomRight = CGPoint(x: br.0, y: br.1)
        bottomLeft = CGPoint(x: bl.0, y: bl.1)
    }

    /// Width ÷ height of the plate as seen, for drawing the replacement plate.
    public var aspect: Double {
        let width = hypot(topRight.x - topLeft.x, topRight.y - topLeft.y)
        let height = hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y)
        return height > 0 ? width / height : 4
    }

    /// Grown by `amount` pixels on every side, to cover the show plate's light border.
    public func expanded(by amount: Double) -> PlateQuad {
        let cx = (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4
        let cy = (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4
        func grow(_ p: CGPoint) -> (Double, Double) {
            let dx = p.x - cx, dy = p.y - cy
            let length = max(hypot(dx, dy), 0.001)
            return (p.x + dx / length * amount, p.y + dy / length * amount)
        }
        return PlateQuad(grow(topLeft), grow(topRight), grow(bottomRight), grow(bottomLeft))
    }
}
