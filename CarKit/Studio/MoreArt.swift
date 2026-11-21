import SwiftUI

// Drawn pieces for the Phase 17 templates (spec §4b Templates, §3 Panorama hero): split-flap tiles,
// rain, wood and brick, and their stickers. All original, drawn in code (ASSETS-LICENSES.md).

/// Fixed pseudo-random numbers, so textures look the same on every render.
struct SeededRandom {
    private var seed: UInt64

    init(_ seed: UInt64) { self.seed = seed }

    mutating func next() -> Double {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(seed >> 11) / Double(1 << 53)
    }
}

// MARK: - Split-flap

/// A field's value on split-flap tiles: white characters on dark tiles with a hairline split.
struct SplitFlapView: View {
    let value: ResolvedField
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            Group {
                switch value.style {
                case .plain:
                    tiles(value.text.isEmpty ? "--" : value.text, size: geo.size)
                case .timer(let date):
                    tile(Text(date, style: .timer), width: geo.size.width * 0.9, height: geo.size.height)
                case .countdown(let date):
                    tile(Text.countdown(to: date), width: geo.size.width * 0.9, height: geo.size.height)
                case .relative(let date):
                    tile(Text(date, style: .relative), width: geo.size.width * 0.9, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tiles(_ text: String, size: CGSize) -> some View {
        // Spaces are a narrow gap between words rather than an empty tile.
        let chars = Array(text.uppercased())
        let spaces = Double(chars.filter { $0 == " " }.count)
        let gap = max(size.height * 0.04, 1)
        let width = min(size.height * 0.7, (size.width - gap * Double(chars.count)) / max(Double(chars.count) - spaces * 0.7, 1))
        let height = min(size.height, width * 1.45)
        HStack(spacing: gap) {
            ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                if ch == " " {
                    Color.clear.frame(width: width * 0.3, height: height)
                } else {
                    tile(Text(String(ch)), width: width, height: height)
                }
            }
        }
    }

    private func tile(_ text: Text, width: Double, height: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: max(width * 0.1, 1.5), style: .continuous)
        return text
            .font(.system(size: height * 0.66, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color(hex: 0xF5F1E6))
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .padding(.horizontal, width * 0.05)
            .frame(width: width, height: height)
            .background(
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color(hex: 0x30343C), Color(hex: 0x23262D)], startPoint: .top, endPoint: .bottom)
                    LinearGradient(colors: [Color(hex: 0x1C1F25), Color(hex: 0x15171C)], startPoint: .top, endPoint: .bottom)
                }
            )
            .overlay(Rectangle().fill(.black.opacity(0.85)).frame(height: max(height * 0.025, 0.8)))
            .clipShape(shape)
            .overlay(shape.stroke(.black.opacity(0.8), lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 1.5, y: 1.2)
    }
}

// MARK: - Backgrounds

/// Blurred city lights (bokeh) behind raindrops on glass.
struct RainBackground: View {
    let a: Color
    let b: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0A0E18), Color(hex: 0x05070C)], startPoint: .top, endPoint: .bottom)
                Canvas { context, size in
                    var random = SeededRandom(0xC0FFEE1234567)
                    context.addFilter(.blur(radius: size.height * 0.035))
                    for i in 0..<22 {
                        let x = random.next() * size.width
                        let y = size.height * (0.35 + random.next() * 0.6)
                        let d = size.height * (0.08 + random.next() * 0.2)
                        let color = i.isMultiple(of: 3) ? Color(hex: 0xFFE2A8) : (i.isMultiple(of: 2) ? a : b)
                        context.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                                     with: .color(color.opacity(0.35 + random.next() * 0.4)))
                    }
                }
                Canvas { context, size in
                    var random = SeededRandom(0xD20915AB)
                    for _ in 0..<70 {
                        let x = random.next() * size.width
                        let y = random.next() * size.height
                        let d = size.height * (0.012 + random.next() * 0.035)
                        let rect = CGRect(x: x, y: y, width: d, height: d * 1.15)
                        context.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.25)))
                        context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.28)), lineWidth: max(d * 0.08, 0.4))
                        context.fill(Path(ellipseIn: CGRect(x: x + d * 0.22, y: y + d * 0.18, width: d * 0.28, height: d * 0.28)),
                                     with: .color(.white.opacity(0.55)))
                    }
                    for _ in 0..<6 {
                        let x = random.next() * size.width
                        let top = random.next() * size.height * 0.5
                        var trail = Path()
                        trail.move(to: CGPoint(x: x, y: top))
                        trail.addCurve(to: CGPoint(x: x + size.height * 0.01, y: top + size.height * 0.4),
                                       control1: CGPoint(x: x - size.height * 0.015, y: top + size.height * 0.12),
                                       control2: CGPoint(x: x + size.height * 0.02, y: top + size.height * 0.26))
                        context.stroke(trail, with: .color(.white.opacity(0.16)), lineWidth: max(size.height * 0.008, 0.6))
                    }
                }
            }
            .frame(width: w, height: h)
        }
    }
}

/// Walnut grain: wavy darker lines across the base colour, with a soft sheen.
enum WoodGrain {
    static func draw(_ context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(0x5EED0F0A4D)
        var y = -size.height * 0.1
        while y < size.height * 1.1 {
            var line = Path()
            let amp = size.height * (0.01 + random.next() * 0.03)
            let phase = random.next() * .pi * 2
            let freq = 2 + random.next() * 3
            line.move(to: CGPoint(x: 0, y: y))
            var x = 0.0
            while x <= size.width {
                line.addLine(to: CGPoint(x: x, y: y + sin(x / max(size.width, 1) * .pi * freq + phase) * amp))
                x += 4
            }
            let dark = random.next() < 0.6
            context.stroke(line, with: .color(dark ? .black.opacity(0.18 + random.next() * 0.2) : Color(hex: 0xE0A060).opacity(0.08)),
                           lineWidth: 0.6 + random.next() * 1.6)
            y += 2.5 + random.next() * 4
        }
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: [.white.opacity(0.1), .clear, .black.opacity(0.3)]),
                                           startPoint: .zero, endPoint: CGPoint(x: size.width * 0.3, y: size.height)))
    }
}

/// A brick wall: staggered bricks with dark mortar and a slight colour variation.
enum BrickWall {
    static func draw(_ context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(0xB21CC0)
        let h = max(size.height / 9, 6), w = h * 2.3
        var row = 0
        var y = 0.0
        while y < size.height {
            var x = row.isMultiple(of: 2) ? 0 : -w / 2
            while x < size.width {
                let rect = CGRect(x: x + 1, y: y + 1, width: w - 2, height: h - 2)
                let shade = random.next()
                context.fill(Path(roundedRect: rect, cornerRadius: 1),
                             with: .color(shade < 0.5 ? .white.opacity(0.03 + shade * 0.05) : .black.opacity(0.1 + (shade - 0.5) * 0.3)))
                context.stroke(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(.black.opacity(0.55)), lineWidth: 1.2)
                x += w
            }
            y += h
            row += 1
        }
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.55)]),
                                           center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: size.height * 0.2,
                                           endRadius: max(size.width, size.height) * 0.75))
    }
}

// MARK: - Stickers

/// A neon tube bent into a rounded frame (turn on the layer's glow for the full effect).
struct NeonTube: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let m = min(geo.size.width, geo.size.height)
            let shape = RoundedRectangle(cornerRadius: m * 0.18, style: .continuous)
            ZStack {
                shape.inset(by: m * 0.04).stroke(color, lineWidth: max(m * 0.035, 1.5))
                shape.inset(by: m * 0.04).stroke(.white.opacity(0.7), lineWidth: max(m * 0.01, 0.5))
            }
            .shadow(color: color.opacity(0.9), radius: m * 0.04)
            .shadow(color: color.opacity(0.6), radius: m * 0.12)
        }
    }
}

/// A thermal-paper ticket with zigzag torn edges top and bottom and faint print lines.
struct ThermalTicket: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let tooth = max(min(w, h) * 0.05, 3)
            var paper = Path()
            paper.move(to: CGPoint(x: 0, y: tooth))
            var x = 0.0
            var up = false
            while x < w {
                x = min(x + tooth, w)
                paper.addLine(to: CGPoint(x: x, y: up ? tooth : 0))
                up.toggle()
            }
            paper.addLine(to: CGPoint(x: w, y: h - tooth))
            up = false
            while x > 0 {
                x = max(x - tooth, 0)
                paper.addLine(to: CGPoint(x: x, y: up ? h - tooth : h))
                up.toggle()
            }
            paper.closeSubpath()
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.45), radius: tooth * 0.6, y: tooth * 0.3))
                layer.fill(paper, with: .color(color))
            }
            context.fill(paper, with: .linearGradient(Gradient(colors: [.black.opacity(0.0), .black.opacity(0.06)]),
                                                      startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
            var dash = Path()
            for y in [h * 0.3, h * 0.72] {
                dash.move(to: CGPoint(x: w * 0.08, y: y))
                dash.addLine(to: CGPoint(x: w * 0.92, y: y))
            }
            context.stroke(dash, with: .color(.black.opacity(0.25)),
                           style: StrokeStyle(lineWidth: max(tooth * 0.12, 0.6), dash: [tooth * 0.4, tooth * 0.3]))
        }
    }
}

/// A generic number plate: black plate, chrome edge and two screws (no country marks).
struct PlateFrame: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let m = min(geo.size.width, geo.size.height)
            let shape = RoundedRectangle(cornerRadius: m * 0.14, style: .continuous)
            ZStack {
                shape.fill(LinearGradient(colors: [Color(hex: 0xF4F6F8), Color(hex: 0x7B8390), Color(hex: 0xE5E7EB), Color(hex: 0x5B6270)],
                                          startPoint: .top, endPoint: .bottom))
                shape.inset(by: m * 0.06).fill(LinearGradient(colors: [Color(hex: 0x1A1C20), color], startPoint: .top, endPoint: .bottom))
                shape.inset(by: m * 0.06).stroke(.white.opacity(0.75), lineWidth: max(m * 0.02, 0.8)).padding(m * 0.04)
                HStack {
                    screw(m)
                    Spacer()
                    screw(m)
                }
                .padding(.horizontal, m * 0.16)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, m * 0.12)
            }
            .shadow(color: .black.opacity(0.5), radius: m * 0.05, y: m * 0.03)
        }
    }

    private func screw(_ m: Double) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xE5E7EB), Color(hex: 0x6B7280)], center: .topLeading, startRadius: 0, endRadius: m * 0.06))
            .frame(width: m * 0.07, height: m * 0.07)
    }
}

/// A radio tuning scale: a dark glass strip with numbered ticks and a red needle.
struct TuningScale: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect, cornerRadius: h * 0.18), with: .color(Color(hex: 0x14110C)))
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: h * 0.18), with: .color(.white.opacity(0.18)), lineWidth: 1)
            let numbers = ["88", "92", "96", "100", "104", "108"]
            let left = w * 0.06, right = w * 0.94
            for i in 0...40 {
                let x = left + (right - left) * Double(i) / 40
                let major = i.isMultiple(of: 8)
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: h * 0.62))
                tick.addLine(to: CGPoint(x: x, y: h * (major ? 0.34 : 0.48)))
                context.stroke(tick, with: .color(color.opacity(major ? 0.95 : 0.55)), lineWidth: max(h * (major ? 0.035 : 0.02), 0.6))
                if major {
                    let label = Text(numbers[i / 8]).font(.system(size: h * 0.2, weight: .semibold, design: .monospaced)).foregroundStyle(color)
                    context.draw(label, at: CGPoint(x: x, y: h * 0.8))
                }
            }
            let nx = left + (right - left) * 0.57
            var needle = Path()
            needle.move(to: CGPoint(x: nx, y: h * 0.12))
            needle.addLine(to: CGPoint(x: nx, y: h * 0.9))
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: Color(hex: 0xFF3B30).opacity(0.8), radius: h * 0.06))
                layer.stroke(needle, with: .color(Color(hex: 0xFF3B30)), lineWidth: max(h * 0.04, 1))
            }
            context.fill(Path(roundedRect: rect, cornerRadius: h * 0.18),
                         with: .linearGradient(Gradient(colors: [.white.opacity(0.1), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.5)))
        }
    }
}

/// A night-mode street map: blocks, roads, a blue route line and a pin.
struct StreetMap: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height, m = min(w, h)
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(Color(hex: 0x1B2130)))
            var random = SeededRandom(0x3A9F17)
            let cell = m * 0.22
            var y = -cell * 0.3
            while y < h {
                var x = -cell * 0.4
                while x < w {
                    let block = CGRect(x: x + m * 0.025, y: y + m * 0.025, width: cell * (0.7 + random.next() * 0.5), height: cell * (0.6 + random.next() * 0.4))
                    context.fill(Path(roundedRect: block, cornerRadius: m * 0.015), with: .color(random.next() < 0.15 ? Color(hex: 0x1F3A2C) : Color(hex: 0x262D3E)))
                    x += cell * 1.2
                }
                y += cell
            }
            var main = Path()
            main.move(to: CGPoint(x: 0, y: h * 0.62))
            main.addCurve(to: CGPoint(x: w, y: h * 0.3), control1: CGPoint(x: w * 0.4, y: h * 0.7), control2: CGPoint(x: w * 0.6, y: h * 0.25))
            var cross = Path()
            cross.move(to: CGPoint(x: w * 0.58, y: 0))
            cross.addLine(to: CGPoint(x: w * 0.52, y: h))
            context.stroke(main, with: .color(Color(hex: 0x56607A)), lineWidth: m * 0.07)
            context.stroke(cross, with: .color(Color(hex: 0x3F475C)), lineWidth: m * 0.045)
            var route = Path()
            route.move(to: CGPoint(x: w * 0.2, y: h * 0.64))
            route.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.48), control1: CGPoint(x: w * 0.35, y: h * 0.67), control2: CGPoint(x: w * 0.45, y: h * 0.55))
            route.addLine(to: CGPoint(x: w * 0.57, y: h * 0.2))
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(0.8), radius: m * 0.03))
                layer.stroke(route, with: .color(color), style: StrokeStyle(lineWidth: m * 0.045, lineCap: .round, lineJoin: .round))
            }
            let pin = CGPoint(x: w * 0.57, y: h * 0.17)
            let r = m * 0.06
            context.fill(Path(ellipseIn: CGRect(x: pin.x - r, y: pin.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xFF3B30)))
            context.fill(Path(ellipseIn: CGRect(x: pin.x - r * 0.4, y: pin.y - r * 0.4, width: r * 0.8, height: r * 0.8)), with: .color(.white))
            let me = CGPoint(x: w * 0.2, y: h * 0.64)
            context.fill(Path(ellipseIn: CGRect(x: me.x - r * 0.8, y: me.y - r * 0.8, width: r * 1.6, height: r * 1.6)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: me.x - r * 0.55, y: me.y - r * 0.55, width: r * 1.1, height: r * 1.1)), with: .color(color))
        }
    }
}

/// An LCD panel: a dark recessed screen with a faint segment grid and a glow in the layer colour.
struct LCDPanel: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let m = min(geo.size.width, geo.size.height)
            let shape = RoundedRectangle(cornerRadius: m * 0.1, style: .continuous)
            ZStack {
                shape.fill(Color(hex: 0x15100A))
                shape.fill(RadialGradient(colors: [color.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: max(geo.size.width, geo.size.height) * 0.6))
                Canvas { context, size in
                    var y = 2.0
                    while y < size.height {
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 0.6)), with: .color(.black.opacity(0.35)))
                        y += 3
                    }
                }
                .clipShape(shape)
                shape.stroke(LinearGradient(colors: [.black, .white.opacity(0.25)], startPoint: .top, endPoint: .bottom), lineWidth: max(m * 0.04, 1))
            }
        }
    }
}

/// A city skyline with lit windows.
struct Skyline: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var random = SeededRandom(0x51C17E)
            for layerIndex in 0..<2 {
                let far = layerIndex == 0
                var x = 0.0
                while x < w {
                    let bw = h * (far ? 0.12 : 0.16) * (0.7 + random.next() * 0.8)
                    let bh = h * (far ? 0.45 : 0.3) * (0.5 + random.next() * 0.9)
                    let rect = CGRect(x: x, y: h - bh, width: bw, height: bh)
                    context.fill(Path(rect), with: .color(far ? Color(hex: 0x1A2033) : Color(hex: 0x0B0E18)))
                    if !far || random.next() < 0.6 {
                        let win = max(h * 0.018, 1.2)
                        var wy = rect.minY + win * 2
                        while wy < rect.maxY - win {
                            var wx = rect.minX + win * 1.5
                            while wx < rect.maxX - win * 1.5 {
                                if random.next() < 0.33 {
                                    context.fill(Path(CGRect(x: wx, y: wy, width: win, height: win * 1.2)),
                                                 with: .color(color.opacity(far ? 0.45 : 0.85)))
                                }
                                wx += win * 2.4
                            }
                            wy += win * 2.6
                        }
                    }
                    x += bw + h * 0.008
                }
            }
        }
    }
}

/// A retro grid floor in perspective, glowing in the layer colour.
struct NeonGrid: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Color(hex: 0x12051F), Color(hex: 0x05020A)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            var grid = Path()
            for i in 0..<10 {
                let t = Double(i) / 9
                let y = h * pow(t, 1.9)
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: w, y: y))
            }
            let vanishing = CGPoint(x: w / 2, y: -h * 0.6)
            for i in -14...14 {
                let bx = w / 2 + Double(i) * w * 0.09
                grid.move(to: vanishing)
                grid.addLine(to: CGPoint(x: bx, y: h))
            }
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(origin: .zero, size: size)))
                layer.addFilter(.shadow(color: color.opacity(0.9), radius: h * 0.03))
                layer.stroke(grid, with: .color(color.opacity(0.85)), lineWidth: max(h * 0.012, 0.8))
            }
            context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.12)),
                         with: .linearGradient(Gradient(colors: [color.opacity(0.5), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.12)))
        }
    }
}

/// A retro sun: a yellow-to-pink disc with horizontal bands cut through its lower half.
struct StripedSun: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let rect = CGRect(x: (size.width - s) / 2, y: (size.height - s) / 2, width: s, height: s)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(0.7), radius: s * 0.08))
                layer.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE45C), color]),
                                                                        startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
                layer.blendMode = .destinationOut
                for i in 0..<6 {
                    let t = Double(i) / 6
                    let y = rect.minY + s * (0.52 + t * 0.46)
                    layer.fill(Path(CGRect(x: rect.minX, y: y, width: s, height: s * (0.02 + t * 0.035))), with: .color(.black))
                }
            }
        }
    }
}
