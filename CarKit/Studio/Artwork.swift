import SwiftUI

// Original artwork for seasonal packs, stickers and templates, drawn in code (no image assets,
// nothing copied). See ASSETS-LICENSES.md.

public struct ArtworkView: View {
    let kind: ArtworkKind
    let color: Color
    var progress: Double = 1

    public init(kind: ArtworkKind, color: Color, progress: Double = 1) {
        self.kind = kind
        self.color = color
        self.progress = progress
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                switch kind {
                case .ketupat: Ketupat(color: color)
                case .crescent: Crescent(color: color)
                case .lantern: Lantern(color: color)
                case .pelita: Pelita(color: color)
                case .diya: Diya(color: color)
                case .stripes: Stripes(color: color)
                case .tree: FestiveTree(color: color)
                case .fireworks: Fireworks(color: color)
                case .gaugeArc: GaugeArc(color: color, progress: progress)
                case .speedLines: SpeedLines(color: color)
                case .heart: Image(systemName: "heart.fill").resizable().scaledToFit().foregroundStyle(color)
                case .star: Image(systemName: "sparkles").resizable().scaledToFit().foregroundStyle(color)
                case .flag: Image(systemName: "flag.checkered").resizable().scaledToFit().foregroundStyle(color)
                }
            }
            .frame(width: kind == .stripes || kind == .speedLines || kind == .gaugeArc ? geo.size.width : size,
                   height: kind == .stripes || kind == .speedLines || kind == .gaugeArc ? geo.size.height : size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// Woven rice-cake diamond with a criss-cross pattern and a little tail.
private struct Ketupat: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + s * 0.06)
            let r = s * 0.38
            var diamond = Path()
            diamond.move(to: CGPoint(x: c.x, y: c.y - r))
            diamond.addLine(to: CGPoint(x: c.x + r, y: c.y))
            diamond.addLine(to: CGPoint(x: c.x, y: c.y + r))
            diamond.addLine(to: CGPoint(x: c.x - r, y: c.y))
            diamond.closeSubpath()
            context.fill(diamond, with: .color(color))
            context.drawLayer { layer in
                layer.clip(to: diamond)
                for i in -4...4 {
                    let offset = Double(i) * r / 4
                    var a = Path()
                    a.move(to: CGPoint(x: c.x - r + offset, y: c.y - r))
                    a.addLine(to: CGPoint(x: c.x + r + offset, y: c.y + r))
                    var b = Path()
                    b.move(to: CGPoint(x: c.x + r + offset, y: c.y - r))
                    b.addLine(to: CGPoint(x: c.x - r + offset, y: c.y + r))
                    layer.stroke(a, with: .color(.black.opacity(0.25)), lineWidth: s * 0.025)
                    layer.stroke(b, with: .color(.white.opacity(0.25)), lineWidth: s * 0.025)
                }
            }
            var tail = Path()
            tail.move(to: CGPoint(x: c.x, y: c.y - r))
            tail.addQuadCurve(to: CGPoint(x: c.x + s * 0.12, y: c.y - r - s * 0.16), control: CGPoint(x: c.x - s * 0.05, y: c.y - r - s * 0.12))
            context.stroke(tail, with: .color(color), lineWidth: s * 0.03)
        }
    }
}

private struct Crescent: View {
    let color: Color

    var body: some View {
        ZStack {
            Image(systemName: "moon.fill")
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(-20))
                .foregroundStyle(color)
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(color)
                .offset(x: 18, y: -14)
        }
    }
}

private struct Lantern: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let body = CGRect(x: size.width / 2 - s * 0.3, y: size.height / 2 - s * 0.25, width: s * 0.6, height: s * 0.5)
            context.fill(Path(ellipseIn: body), with: .color(color))
            for i in 1...3 {
                let x = body.minX + body.width * Double(i) / 4
                var rib = Path()
                rib.move(to: CGPoint(x: x, y: body.minY + 4))
                rib.addQuadCurve(to: CGPoint(x: x, y: body.maxY - 4), control: CGPoint(x: x + (x - body.midX) * 0.6, y: body.midY))
                context.stroke(rib, with: .color(.black.opacity(0.25)), lineWidth: s * 0.02)
            }
            let gold = Color(hex: 0xF5C542)
            context.fill(Path(CGRect(x: body.midX - s * 0.14, y: body.minY - s * 0.06, width: s * 0.28, height: s * 0.07)), with: .color(gold))
            context.fill(Path(CGRect(x: body.midX - s * 0.14, y: body.maxY - s * 0.01, width: s * 0.28, height: s * 0.07)), with: .color(gold))
            var tassel = Path()
            tassel.move(to: CGPoint(x: body.midX, y: body.maxY + s * 0.06))
            tassel.addLine(to: CGPoint(x: body.midX, y: body.maxY + s * 0.2))
            context.stroke(tassel, with: .color(gold), lineWidth: s * 0.03)
        }
    }
}

/// A row of small oil lamps (pelita) for Raya nights.
private struct Pelita: View {
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill").foregroundStyle(Color(hex: 0xF5A524))
                    Capsule().fill(color).frame(width: 10, height: 18)
                }
            }
        }
    }
}

private struct Diya: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let cx = size.width / 2, base = size.height / 2 + s * 0.15
            var bowl = Path()
            bowl.move(to: CGPoint(x: cx - s * 0.35, y: base - s * 0.08))
            bowl.addQuadCurve(to: CGPoint(x: cx + s * 0.35, y: base - s * 0.08), control: CGPoint(x: cx, y: base + s * 0.3))
            bowl.closeSubpath()
            context.fill(bowl, with: .color(color))
            var flame = Path()
            flame.move(to: CGPoint(x: cx, y: base - s * 0.48))
            flame.addQuadCurve(to: CGPoint(x: cx, y: base - s * 0.1), control: CGPoint(x: cx + s * 0.16, y: base - s * 0.2))
            flame.addQuadCurve(to: CGPoint(x: cx, y: base - s * 0.48), control: CGPoint(x: cx - s * 0.16, y: base - s * 0.2))
            context.fill(flame, with: .color(Color(hex: 0xF5A524)))
        }
    }
}

/// Red and white stripes with a navy canton and a gold crescent (Merdeka mood, stylised).
private struct Stripes: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<14, id: \.self) { i in
                        (i.isMultiple(of: 2) ? Color(hex: 0xCC0001) : Color.white)
                    }
                }
                Color(hex: 0x010066)
                    .frame(width: geo.size.width * 0.45, height: geo.size.height * 0.57)
                    .overlay {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(Color(hex: 0xFFCC00))
                            .font(.system(size: geo.size.height * 0.25))
                    }
            }
        }
        .opacity(0.9)
    }
}

private struct FestiveTree: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let cx = size.width / 2, top = size.height / 2 - s * 0.42
            for tier in 0..<3 {
                let y = top + Double(tier) * s * 0.2
                let half = s * (0.16 + Double(tier) * 0.09)
                var tri = Path()
                tri.move(to: CGPoint(x: cx, y: y))
                tri.addLine(to: CGPoint(x: cx + half, y: y + s * 0.3))
                tri.addLine(to: CGPoint(x: cx - half, y: y + s * 0.3))
                tri.closeSubpath()
                context.fill(tri, with: .color(color))
            }
            context.fill(Path(CGRect(x: cx - s * 0.05, y: top + s * 0.7, width: s * 0.1, height: s * 0.12)), with: .color(Color(hex: 0x8B5A2B)))
            for (dx, dy) in [(-0.1, 0.3), (0.12, 0.45), (-0.15, 0.6), (0.05, 0.2)] {
                context.fill(Path(ellipseIn: CGRect(x: cx + dx * s - 4, y: top + dy * s - 4, width: 8, height: 8)), with: .color(Color(hex: 0xF5C542)))
            }
        }
    }
}

private struct Fireworks: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let bursts: [(Double, Double, Double)] = [(0.3, 0.35, 0.22), (0.7, 0.3, 0.18), (0.55, 0.7, 0.15)]
            for (bx, by, br) in bursts {
                let c = CGPoint(x: size.width * bx, y: size.height * by)
                let r = min(size.width, size.height) * br
                for i in 0..<12 {
                    let angle = Double(i) / 12 * 2 * .pi
                    var ray = Path()
                    ray.move(to: CGPoint(x: c.x + cos(angle) * r * 0.3, y: c.y + sin(angle) * r * 0.3))
                    ray.addLine(to: CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r))
                    context.stroke(ray, with: .color(i.isMultiple(of: 2) ? color : Color(hex: 0xF5C542)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
        }
    }
}

/// A 240° gauge arc with a filled part for `progress`.
private struct GaugeArc: View {
    let color: Color
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .trim(from: 0, to: 2.0 / 3.0)
                    .stroke(color.opacity(0.25), style: StrokeStyle(lineWidth: s * 0.09, lineCap: .round))
                Circle()
                    .trim(from: 0, to: 2.0 / 3.0 * min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: s * 0.09, lineCap: .round))
            }
            .rotationEffect(.degrees(150))
            .frame(width: s * 0.9, height: s * 0.9)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SpeedLines: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            for i in 0..<5 {
                let y = size.height * (0.2 + Double(i) * 0.15)
                var line = Path()
                line.move(to: CGPoint(x: size.width * (0.1 + Double(i % 2) * 0.1), y: y))
                line.addLine(to: CGPoint(x: size.width * (0.7 + Double(i % 3) * 0.1), y: y))
                context.stroke(line, with: .color(color.opacity(0.6 - Double(i) * 0.08)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }
}

/// Background textures (carbon weave, brushed metal, dots).
public struct TextureView: View {
    let texture: DesignTexture
    let base: Color

    public init(texture: DesignTexture, base: Color) {
        self.texture = texture
        self.base = base
    }

    public var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            switch texture {
            case .carbon:
                let cell = 8.0
                var y = 0.0
                var row = 0
                while y < size.height {
                    var x = row.isMultiple(of: 2) ? 0 : cell
                    while x < size.width {
                        context.fill(Path(CGRect(x: x, y: y, width: cell, height: cell / 2)), with: .color(.white.opacity(0.06)))
                        context.fill(Path(CGRect(x: x + cell, y: y + cell / 2, width: cell, height: cell / 2)), with: .color(.black.opacity(0.25)))
                        x += cell * 2
                    }
                    y += cell / 2
                    row += 1
                }
            case .brushed:
                var y = 0.0
                var i = 0
                while y < size.height {
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white.opacity(i % 3 == 0 ? 0.06 : 0.025)))
                    y += 2
                    i += 1
                }
            case .dots:
                var y = 6.0
                while y < size.height {
                    var x = 6.0
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.12)))
                        x += 12
                    }
                    y += 12
                }
            }
        }
    }
}
