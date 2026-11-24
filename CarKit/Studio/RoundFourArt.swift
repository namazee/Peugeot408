import SwiftUI

// Phase 19 pieces (spec §4b Templates, §3 Panorama hero): the compass and glow-orb layers and the
// new stickers. All original, drawn in code (ASSETS-LICENSES.md).

private func spot(_ c: CGPoint, _ r: Double, _ a: Double) -> CGPoint {
    CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
}

// MARK: - Layers

/// A compass rose: ticks, N E S W, an eight-point star and a needle turned by `progress` (0…1 = a full turn).
struct CompassView: View {
    let progress: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = s * 0.47
            let rim = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rim), with: .linearGradient(Gradient(colors: [Color(hex: 0xC9A86A), Color(hex: 0x5C4520)]),
                                                                      startPoint: CGPoint(x: rim.minX, y: rim.minY), endPoint: CGPoint(x: rim.maxX, y: rim.maxY)))
            let fr = r * 0.9
            let face = CGRect(x: c.x - fr, y: c.y - fr, width: fr * 2, height: fr * 2)
            context.fill(Path(ellipseIn: face), with: .radialGradient(Gradient(colors: [Color(hex: 0xF4EAD2), Color(hex: 0xCDBB92)]),
                                                                      center: c, startRadius: 0, endRadius: fr))
            let ink = Color(hex: 0x2B2418)
            for i in 0..<72 {
                let a = Double(i) / 72 * 2 * .pi - .pi / 2
                let major = i % 9 == 0
                var tick = Path()
                tick.move(to: spot(c, fr * (major ? 0.82 : 0.89), a))
                tick.addLine(to: spot(c, fr * 0.96, a))
                context.stroke(tick, with: .color(ink.opacity(major ? 0.9 : 0.45)), lineWidth: major ? s * 0.012 : s * 0.005)
            }
            for (index, letter) in ["N", "E", "S", "W"].enumerated() {
                let a = Double(index) * .pi / 2 - .pi / 2
                context.draw(Text(letter).font(.system(size: s * 0.1, weight: .heavy, design: .serif))
                                .foregroundColor(index == 0 ? Color(hex: 0xB42318) : ink),
                             at: spot(c, fr * 0.68, a))
            }
            // Eight-point star.
            for i in 0..<8 {
                let a = Double(i) * .pi / 4 - .pi / 2
                let long = i.isMultiple(of: 2)
                let tip = spot(c, fr * (long ? 0.52 : 0.34), a)
                let left = spot(c, fr * 0.09, a - .pi / 2)
                let right = spot(c, fr * 0.09, a + .pi / 2)
                var half1 = Path(); half1.move(to: c); half1.addLine(to: left); half1.addLine(to: tip); half1.closeSubpath()
                var half2 = Path(); half2.move(to: c); half2.addLine(to: right); half2.addLine(to: tip); half2.closeSubpath()
                context.fill(half1, with: .color(ink.opacity(long ? 0.55 : 0.3)))
                context.fill(half2, with: .color(ink.opacity(long ? 0.25 : 0.15)))
            }
            // Needle: north half red (or the layer colour), south half white.
            let a = min(max(progress, 0), 1) * 2 * .pi - .pi / 2
            let w = s * 0.045
            var north = Path()
            north.move(to: spot(c, fr * 0.78, a)); north.addLine(to: spot(c, w, a + .pi / 2)); north.addLine(to: spot(c, w, a - .pi / 2)); north.closeSubpath()
            var south = Path()
            south.move(to: spot(c, fr * 0.6, a + .pi)); south.addLine(to: spot(c, w, a + .pi / 2)); south.addLine(to: spot(c, w, a - .pi / 2)); south.closeSubpath()
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.4), radius: s * 0.015, y: s * 0.01))
                layer.fill(north, with: .color(color))
                layer.fill(south, with: .color(Color(hex: 0xF8F5EC)))
                layer.stroke(south, with: .color(ink.opacity(0.4)), lineWidth: 0.8)
            }
            let hub = CGRect(x: c.x - s * 0.04, y: c.y - s * 0.04, width: s * 0.08, height: s * 0.08)
            context.fill(Path(ellipseIn: hub), with: .color(Color(hex: 0xC9A86A)))
            context.stroke(Path(ellipseIn: hub), with: .color(ink.opacity(0.6)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// A glass sphere filled with glowing liquid up to `progress`, with a soft glow and a highlight.
struct GlowOrbView: View {
    let progress: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = s * 0.44
            let orb = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            let sphere = Path(ellipseIn: orb)
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: s * 0.08))
                layer.fill(Path(ellipseIn: orb.insetBy(dx: -s * 0.02, dy: -s * 0.02)), with: .color(color.opacity(0.35 + 0.4 * min(max(progress, 0), 1))))
            }
            context.fill(sphere, with: .radialGradient(Gradient(colors: [Color(hex: 0x1B2130), Color(hex: 0x05070C)]),
                                                       center: CGPoint(x: c.x, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.2))
            let level = orb.maxY - orb.height * min(max(progress, 0), 1)
            context.drawLayer { layer in
                layer.clip(to: sphere)
                var liquid = Path()
                liquid.move(to: CGPoint(x: orb.minX, y: level))
                var x = orb.minX
                while x <= orb.maxX {
                    liquid.addLine(to: CGPoint(x: x, y: level + sin((x - orb.minX) / orb.width * .pi * 3) * s * 0.012))
                    x += max(orb.width / 60, 1)
                }
                liquid.addLine(to: CGPoint(x: orb.maxX, y: orb.maxY))
                liquid.addLine(to: CGPoint(x: orb.minX, y: orb.maxY))
                liquid.closeSubpath()
                layer.addFilter(.shadow(color: color, radius: s * 0.04))
                layer.fill(liquid, with: .linearGradient(Gradient(colors: [color.opacity(0.95), color.opacity(0.55)]),
                                                         startPoint: CGPoint(x: c.x, y: level), endPoint: CGPoint(x: c.x, y: orb.maxY)))
            }
            // Bubbles.
            var random = SeededRandom(0x0B5EED)
            for _ in 0..<7 {
                let bx = orb.minX + orb.width * (0.25 + random.next() * 0.5)
                let by = level + (orb.maxY - level) * (0.15 + random.next() * 0.7)
                let br = s * (0.008 + random.next() * 0.014)
                if by < orb.maxY - br * 2 {
                    context.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)), with: .color(.white.opacity(0.45)))
                }
            }
            context.stroke(sphere, with: .color(.white.opacity(0.55)), lineWidth: max(s * 0.012, 1))
            context.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.62, y: c.y - r * 0.78, width: r * 0.6, height: r * 0.32)), with: .color(.white.opacity(0.28)))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Stickers

/// A night highway in perspective: dark tarmac, lane dashes, and long red and white light trails.
struct LightTrails: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let vanish = CGPoint(x: w * 0.5, y: h * 0.08)
            var road = Path()
            road.move(to: CGPoint(x: vanish.x - w * 0.02, y: vanish.y))
            road.addLine(to: CGPoint(x: vanish.x + w * 0.02, y: vanish.y))
            road.addLine(to: CGPoint(x: w, y: h))
            road.addLine(to: CGPoint(x: 0, y: h))
            road.closeSubpath()
            context.fill(road, with: .linearGradient(Gradient(colors: [Color(hex: 0x14161C), Color(hex: 0x050608)]),
                                                     startPoint: vanish, endPoint: CGPoint(x: vanish.x, y: h)))
            for lane in [-0.18, 0.18] {
                for k in 0..<9 {
                    let t0 = pow(Double(k) / 9, 1.8), t1 = pow((Double(k) + 0.45) / 9, 1.8)
                    func at(_ t: Double) -> CGPoint { CGPoint(x: vanish.x + (w * (0.5 + lane) - vanish.x) * t, y: vanish.y + (h - vanish.y) * t) }
                    var dash = Path()
                    dash.move(to: at(t0)); dash.addLine(to: at(t1))
                    context.stroke(dash, with: .color(.white.opacity(0.45)), lineWidth: 1 + 3 * t1)
                }
            }
            let trails: [(Double, Color)] = [(-0.42, Color(hex: 0xFF2D2D)), (-0.32, Color(hex: 0xFF5A36)), (-0.26, Color(hex: 0xFF2D2D)),
                                             (0.26, color), (0.34, color), (0.44, Color(hex: 0xFFE7B0))]
            for (offset, tint) in trails {
                var trail = Path()
                trail.move(to: CGPoint(x: vanish.x + offset * w * 0.02, y: vanish.y))
                trail.addQuadCurve(to: CGPoint(x: w * (0.5 + offset * 1.2), y: h),
                                   control: CGPoint(x: w * (0.5 + offset * 0.35), y: h * 0.55))
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: h * 0.012))
                    layer.stroke(trail, with: .color(tint.opacity(0.9)), lineWidth: h * 0.022)
                }
                context.stroke(trail, with: .color(.white.opacity(0.55)), lineWidth: h * 0.005)
            }
        }
    }
}

/// Green paddy terraces in curved bands, with planting rows and a sheen of water.
struct PaddyTerraces: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let bands = 6
            for i in 0..<bands {
                let top = h * (Double(i) / Double(bands)) * 0.92
                let depth = Double(i) / Double(bands - 1)
                var band = Path()
                band.move(to: CGPoint(x: 0, y: top + h * 0.04))
                band.addQuadCurve(to: CGPoint(x: w, y: top + h * 0.02), control: CGPoint(x: w * 0.5, y: top - h * 0.08))
                band.addLine(to: CGPoint(x: w, y: h))
                band.addLine(to: CGPoint(x: 0, y: h))
                band.closeSubpath()
                context.fill(band, with: .color(color.mix(with: .black, by: 0.45 - depth * 0.4)))
                var edge = Path()
                edge.move(to: CGPoint(x: 0, y: top + h * 0.04))
                edge.addQuadCurve(to: CGPoint(x: w, y: top + h * 0.02), control: CGPoint(x: w * 0.5, y: top - h * 0.08))
                context.stroke(edge, with: .color(Color(hex: 0xE9F7C8).opacity(0.35 + depth * 0.3)), lineWidth: 1 + depth * 2)
                var x = w * 0.02
                while x < w {
                    var row = Path()
                    row.move(to: CGPoint(x: x, y: top + h * 0.06))
                    row.addLine(to: CGPoint(x: x + (x - w / 2) * 0.05, y: top + h * (0.1 + depth * 0.05)))
                    context.stroke(row, with: .color(Color(hex: 0x0E3B12).opacity(0.35)), lineWidth: 1)
                    x += w * (0.035 - depth * 0.015)
                }
            }
        }
    }
}

/// Rainforest canopy: dark crowns along the top and sides, with light rays coming through.
struct Rainforest: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: w * 0.012))
                for (index, x) in [0.3, 0.45, 0.55, 0.7].enumerated() {
                    var ray = Path()
                    ray.move(to: CGPoint(x: w * x, y: 0))
                    ray.addLine(to: CGPoint(x: w * (x + 0.04), y: 0))
                    ray.addLine(to: CGPoint(x: w * (x + 0.12 - Double(index) * 0.06), y: h))
                    ray.addLine(to: CGPoint(x: w * (x - 0.04 - Double(index) * 0.06), y: h))
                    ray.closeSubpath()
                    layer.fill(ray, with: .linearGradient(Gradient(colors: [color.opacity(0.5), color.opacity(0)]),
                                                          startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                }
            }
            var random = SeededRandom(0xF0E5A7)
            let shades: [UInt32] = [0x0B2A14, 0x123D1C, 0x1B5227]
            for layerIndex in 0..<3 {
                let tint = Color(hex: shades[layerIndex])
                var x = -w * 0.05
                while x < w * 1.05 {
                    let edge = abs(x / w - 0.5) * 2
                    let r = h * (0.08 + random.next() * 0.08) * (0.7 + Double(layerIndex) * 0.15)
                    let y = h * (0.02 + Double(layerIndex) * 0.06) + edge * edge * h * 0.55 * random.next()
                    context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 1.7)), with: .color(tint))
                    x += r * 0.9
                }
            }
            for side in [0.0, 1.0] {
                var trunk = Path()
                trunk.addRect(CGRect(x: side == 0 ? w * 0.04 : w * 0.93, y: h * 0.2, width: w * 0.025, height: h * 0.8))
                context.fill(trunk, with: .color(Color(hex: 0x081A0D)))
            }
        }
    }
}

/// A lightning bolt with a branch and a glow.
struct LightningBolt: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let points: [(Double, Double)] = [(0.55, 0), (0.45, 0.28), (0.6, 0.34), (0.42, 0.64), (0.56, 0.68), (0.38, 1)]
            var bolt = Path()
            bolt.move(to: CGPoint(x: w * points[0].0, y: h * points[0].1))
            for p in points.dropFirst() { bolt.addLine(to: CGPoint(x: w * p.0, y: h * p.1)) }
            var branch = Path()
            branch.move(to: CGPoint(x: w * 0.6, y: h * 0.34))
            branch.addLine(to: CGPoint(x: w * 0.72, y: h * 0.46))
            branch.addLine(to: CGPoint(x: w * 0.68, y: h * 0.5))
            branch.addLine(to: CGPoint(x: w * 0.82, y: h * 0.66))
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: min(w, h) * 0.04))
                layer.stroke(bolt, with: .color(color), lineWidth: min(w, h) * 0.08)
            }
            context.stroke(branch, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: min(w, h) * 0.012, lineJoin: .round))
            context.stroke(bolt, with: .color(color), style: StrokeStyle(lineWidth: min(w, h) * 0.028, lineJoin: .round))
            context.stroke(bolt, with: .color(.white), style: StrokeStyle(lineWidth: min(w, h) * 0.01, lineJoin: .round))
        }
    }
}

/// Rows of fluorescent strip lights on a garage ceiling, in perspective.
struct StripLights: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            for row in 0..<4 {
                let t = Double(row) / 3
                let y = h * (0.08 + t * 0.7)
                let span = w * (0.18 + t * 0.12)
                let thick = h * (0.04 + t * 0.05)
                for x in [w * 0.17, w * 0.5, w * 0.83] {
                    let rect = CGRect(x: x - span / 2, y: y, width: span, height: thick)
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: thick * 1.2))
                        layer.fill(Path(roundedRect: rect.insetBy(dx: -thick, dy: -thick * 0.5), cornerRadius: thick), with: .color(color.opacity(0.55)))
                    }
                    context.fill(Path(roundedRect: rect, cornerRadius: thick / 2), with: .color(.white))
                    context.stroke(Path(roundedRect: rect, cornerRadius: thick / 2), with: .color(color.opacity(0.6)), lineWidth: 1)
                }
            }
        }
    }
}

/// Two stacks of tyres at the sides, with tread grooves and a painted stripe.
struct TyreStack: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let tyreW = w * 0.12, tyreH = h * 0.16
            for column in [0.07, 0.93] {
                let count = 5
                for i in 0..<count {
                    let y = h - tyreH * Double(i + 1) * 0.92
                    let rect = CGRect(x: w * column - tyreW / 2, y: y, width: tyreW, height: tyreH)
                    context.fill(Path(roundedRect: rect, cornerRadius: tyreH * 0.35), with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x2A2D33), Color(hex: 0x0A0B0D), Color(hex: 0x2A2D33)]),
                        startPoint: CGPoint(x: rect.minX, y: rect.midY), endPoint: CGPoint(x: rect.maxX, y: rect.midY)))
                    var tread = Path()
                    var x = rect.minX + tyreW * 0.1
                    while x < rect.maxX - tyreW * 0.08 {
                        tread.move(to: CGPoint(x: x, y: rect.minY + tyreH * 0.18))
                        tread.addLine(to: CGPoint(x: x + tyreW * 0.03, y: rect.maxY - tyreH * 0.18))
                        x += tyreW * 0.09
                    }
                    context.stroke(tread, with: .color(.black.opacity(0.7)), lineWidth: 1)
                    if i.isMultiple(of: 2) {
                        context.fill(Path(CGRect(x: rect.minX + tyreW * 0.06, y: rect.midY - tyreH * 0.06, width: tyreW * 0.88, height: tyreH * 0.12)),
                                     with: .color(color.opacity(0.9)))
                    }
                }
            }
        }
    }
}

/// Technical-drawing dimension lines: extension lines, arrows and a dashed centre line.
struct DimensionLines: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let line = StrokeStyle(lineWidth: max(h * 0.006, 1))
            func arrow(_ from: CGPoint, _ to: CGPoint) {
                var p = Path(); p.move(to: from); p.addLine(to: to)
                context.stroke(p, with: .color(color), style: line)
                for (tip, other) in [(from, to), (to, from)] {
                    let a = atan2(other.y - tip.y, other.x - tip.x)
                    var head = Path()
                    head.move(to: tip)
                    head.addLine(to: CGPoint(x: tip.x + cos(a + 0.4) * h * 0.04, y: tip.y + sin(a + 0.4) * h * 0.04))
                    head.addLine(to: CGPoint(x: tip.x + cos(a - 0.4) * h * 0.04, y: tip.y + sin(a - 0.4) * h * 0.04))
                    head.closeSubpath()
                    context.fill(head, with: .color(color))
                }
            }
            // Length along the bottom, height up the right side.
            arrow(CGPoint(x: w * 0.08, y: h * 0.94), CGPoint(x: w * 0.92, y: h * 0.94))
            arrow(CGPoint(x: w * 0.96, y: h * 0.12), CGPoint(x: w * 0.96, y: h * 0.86))
            var ext = Path()
            for x in [0.08, 0.92] { ext.move(to: CGPoint(x: w * x, y: h * 0.7)); ext.addLine(to: CGPoint(x: w * x, y: h * 0.98)) }
            for y in [0.12, 0.86] { ext.move(to: CGPoint(x: w * 0.8, y: h * y)); ext.addLine(to: CGPoint(x: w * 0.99, y: h * y)) }
            context.stroke(ext, with: .color(color.opacity(0.7)), style: StrokeStyle(lineWidth: max(h * 0.004, 0.8)))
            var centre = Path()
            centre.move(to: CGPoint(x: w * 0.04, y: h * 0.55)); centre.addLine(to: CGPoint(x: w * 0.9, y: h * 0.55))
            context.stroke(centre, with: .color(color.opacity(0.5)), style: StrokeStyle(lineWidth: max(h * 0.003, 0.7), dash: [h * 0.06, h * 0.02, h * 0.01, h * 0.02]))
            for x in [0.27, 0.73] {
                let r = h * 0.11
                context.stroke(Path(ellipseIn: CGRect(x: w * x - r, y: h * 0.78 - r, width: r * 2, height: r * 2)), with: .color(color.opacity(0.6)),
                               style: StrokeStyle(lineWidth: max(h * 0.004, 0.8), dash: [h * 0.02, h * 0.015]))
            }
        }
    }
}

/// A cassette tape: dark shell, paper label in the layer colour, a window with two toothed reels and screws.
struct CassetteTape: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let shell = CGRect(x: w * 0.02, y: h * 0.04, width: w * 0.96, height: h * 0.92)
            context.fill(Path(roundedRect: shell, cornerRadius: h * 0.06), with: .linearGradient(
                Gradient(colors: [Color(hex: 0x2B2E35), Color(hex: 0x111317)]), startPoint: CGPoint(x: 0, y: shell.minY), endPoint: CGPoint(x: 0, y: shell.maxY)))
            context.stroke(Path(roundedRect: shell, cornerRadius: h * 0.06), with: .color(.white.opacity(0.15)), lineWidth: 1)
            let label = CGRect(x: w * 0.08, y: h * 0.1, width: w * 0.84, height: h * 0.6)
            context.fill(Path(roundedRect: label, cornerRadius: h * 0.03), with: .color(Color(hex: 0xF5F0E1)))
            context.fill(Path(CGRect(x: label.minX, y: label.minY + label.height * 0.62, width: label.width, height: label.height * 0.12)), with: .color(color))
            let window = CGRect(x: w * 0.26, y: h * 0.42, width: w * 0.48, height: h * 0.2)
            context.fill(Path(roundedRect: window, cornerRadius: window.height / 2), with: .color(Color(hex: 0x1A1C20)))
            for x in [window.minX + window.height * 0.6, window.maxX - window.height * 0.6] {
                let r = window.height * 0.38
                let c = CGPoint(x: x, y: window.midY)
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xE8E2D0)))
                for k in 0..<6 {
                    let a = Double(k) / 6 * 2 * .pi
                    var tooth = Path()
                    tooth.move(to: spot(c, r * 0.3, a)); tooth.addLine(to: spot(c, r * 0.62, a))
                    context.stroke(tooth, with: .color(Color(hex: 0x2B2E35)), lineWidth: max(r * 0.16, 1))
                }
            }
            var trapezoid = Path()
            trapezoid.move(to: CGPoint(x: w * 0.22, y: shell.maxY))
            trapezoid.addLine(to: CGPoint(x: w * 0.28, y: h * 0.76))
            trapezoid.addLine(to: CGPoint(x: w * 0.72, y: h * 0.76))
            trapezoid.addLine(to: CGPoint(x: w * 0.78, y: shell.maxY))
            context.fill(trapezoid, with: .color(Color(hex: 0x1A1C20)))
            for (x, y) in [(0.06, 0.1), (0.94, 0.1), (0.06, 0.88), (0.94, 0.88)] {
                let r = h * 0.025
                context.fill(Path(ellipseIn: CGRect(x: w * x - r, y: h * y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0x9CA3AF)))
            }
        }
    }
}

/// Neon-sign hardware: a thin wire with metal clips and standoffs along it.
struct TubeClips: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var wire = Path()
            wire.move(to: CGPoint(x: w * 0.02, y: h * 0.5))
            wire.addLine(to: CGPoint(x: w * 0.98, y: h * 0.5))
            context.stroke(wire, with: .color(.black.opacity(0.5)), lineWidth: max(h * 0.04, 1))
            for x in [0.12, 0.38, 0.62, 0.88] {
                let r = h * 0.22
                let c = CGPoint(x: w * x, y: h * 0.5)
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xE5E7EB), Color(hex: 0x6B7280)]), startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: CGPoint(x: c.x + r, y: c.y + r)))
                context.stroke(Path(roundedRect: CGRect(x: c.x - r * 0.5, y: c.y - r * 1.8, width: r, height: r * 3.6), cornerRadius: r * 0.3),
                               with: .color(color.opacity(0.8)), lineWidth: max(h * 0.05, 1))
            }
        }
    }
}

/// A day-calendar page: a coloured header with metal rings, and a white page below.
struct CalendarRings: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let page = CGRect(x: w * 0.04, y: h * 0.08, width: w * 0.92, height: h * 0.9)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.35), radius: h * 0.03, y: h * 0.02))
                layer.fill(Path(roundedRect: page, cornerRadius: h * 0.05), with: .color(Color(hex: 0xFBFAF6)))
            }
            var header = Path()
            header.addRoundedRect(in: CGRect(x: page.minX, y: page.minY, width: page.width, height: page.height * 0.26),
                                  cornerSize: CGSize(width: h * 0.05, height: h * 0.05))
            header.addRect(CGRect(x: page.minX, y: page.minY + page.height * 0.13, width: page.width, height: page.height * 0.13))
            context.fill(header, with: .color(color))
            var tear = Path()
            var x = page.minX
            while x < page.maxX {
                tear.addEllipse(in: CGRect(x: x, y: page.maxY - h * 0.012, width: h * 0.012, height: h * 0.012))
                x += h * 0.03
            }
            context.fill(tear, with: .color(.black.opacity(0.12)))
            for ringX in [0.3, 0.7] {
                let ring = CGRect(x: w * ringX - w * 0.035, y: 0, width: w * 0.07, height: h * 0.16)
                context.stroke(Path(roundedRect: ring, cornerRadius: w * 0.035), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xF3F4F6), Color(hex: 0x6B7280)]), startPoint: CGPoint(x: ring.minX, y: 0), endPoint: CGPoint(x: ring.maxX, y: 0)),
                               lineWidth: max(w * 0.014, 1.5))
            }
        }
    }
}

/// A round postmark with wavy cancellation lines.
struct Postmark: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let r = h * 0.44
            let c = CGPoint(x: r + h * 0.04, y: h / 2)
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color), lineWidth: max(h * 0.035, 1))
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r * 0.72, y: c.y - r * 0.72, width: r * 1.44, height: r * 1.44)), with: .color(color), lineWidth: max(h * 0.02, 0.8))
            var bar = Path()
            bar.move(to: CGPoint(x: c.x - r * 0.55, y: c.y)); bar.addLine(to: CGPoint(x: c.x + r * 0.55, y: c.y))
            context.stroke(bar, with: .color(color), lineWidth: max(h * 0.03, 1))
            for i in 0..<4 {
                let y = h * (0.2 + Double(i) * 0.2)
                var wave = Path()
                wave.move(to: CGPoint(x: c.x + r * 1.1, y: y))
                var x = c.x + r * 1.1
                while x <= w {
                    wave.addLine(to: CGPoint(x: x, y: y + sin((x - c.x) / h * .pi * 2.2) * h * 0.05))
                    x += 2
                }
                context.stroke(wave, with: .color(color), lineWidth: max(h * 0.025, 1))
            }
        }
        .opacity(0.85)
    }
}

/// A postage stamp: white paper with a perforated edge and a thin inner frame in the layer colour.
struct StampEdge: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let paper = CGRect(origin: .zero, size: size)
            context.fill(Path(paper), with: .color(Color(hex: 0xFBF7EC)))
            let hole = min(w, h) * 0.05
            context.blendMode = .destinationOut
            var x = hole
            while x < w {
                context.fill(Path(ellipseIn: CGRect(x: x - hole / 2, y: -hole / 2, width: hole, height: hole)), with: .color(.black))
                context.fill(Path(ellipseIn: CGRect(x: x - hole / 2, y: h - hole / 2, width: hole, height: hole)), with: .color(.black))
                x += hole * 1.8
            }
            var y = hole
            while y < h {
                context.fill(Path(ellipseIn: CGRect(x: -hole / 2, y: y - hole / 2, width: hole, height: hole)), with: .color(.black))
                context.fill(Path(ellipseIn: CGRect(x: w - hole / 2, y: y - hole / 2, width: hole, height: hole)), with: .color(.black))
                y += hole * 1.8
            }
            context.blendMode = .normal
            let frame = paper.insetBy(dx: hole * 1.4, dy: hole * 1.4)
            context.stroke(Path(frame), with: .color(color), lineWidth: max(hole * 0.25, 1))
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }
}
