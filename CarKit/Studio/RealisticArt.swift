import SwiftUI

// Drawn pieces for the realistic templates (spec §4b, Phase 16): dials, the odometer, the frosted
// and live-sky backgrounds and their stickers. All original, drawn in code (ASSETS-LICENSES.md).

private func point(_ c: CGPoint, _ r: Double, _ a: Double) -> CGPoint {
    CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
}

private var chrome: Gradient { Gradient(colors: [Color(hex: 0xF4F6F8), Color(hex: 0x6B7280), Color(hex: 0xE5E7EB), Color(hex: 0x4B5563), Color(hex: 0xF4F6F8)]) }
private var dialRed: Color { Color(hex: 0xE5484D) }

// MARK: - Dial

/// A realistic dial: chrome bezel, dark face, ticks, numbers and a needle at `progress` (0…1).
struct DialView: View {
    let style: DialStyle
    let needle: Color
    let progress: Double

    var body: some View {
        Canvas { context, size in
            switch style {
            case .instrument: Self.instrument(&context, size: size, needle: needle, progress: progress)
            case .fuel: Self.fuel(&context, size: size, needle: needle, progress: progress)
            case .tachometer: Self.tachometer(&context, size: size, needle: needle, progress: progress)
            }
        }
        .accessibilityHidden(true)
    }

    private static func instrument(_ context: inout GraphicsContext, size: CGSize, needle: Color, progress: Double) {
        let s = min(size.width, size.height)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = s * 0.47
        context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                     with: .conicGradient(chrome, center: c, angle: .degrees(-35)))
        let fr = r * 0.89
        let faceRect = CGRect(x: c.x - fr, y: c.y - fr, width: fr * 2, height: fr * 2)
        context.fill(Path(ellipseIn: faceRect),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0x2A2F38), Color(hex: 0x08090C)]),
                                           center: CGPoint(x: c.x, y: c.y - fr * 0.35), startRadius: 0, endRadius: fr * 1.25))
        context.stroke(Path(ellipseIn: faceRect.insetBy(dx: fr * 0.02, dy: fr * 0.02)), with: .color(.white.opacity(0.08)), lineWidth: 1)

        let start = 135.0, sweep = 270.0
        func angle(_ f: Double) -> Double { (start + sweep * f) * .pi / 180 }
        var redZone = Path()
        redZone.addArc(center: c, radius: fr * 0.885, startAngle: .radians(angle(0.8)), endAngle: .radians(angle(1)), clockwise: false)
        context.stroke(redZone, with: .color(dialRed.opacity(0.9)), lineWidth: fr * 0.07)

        for i in 0...40 {
            let f = Double(i) / 40, a = angle(f), major = i % 5 == 0
            var tick = Path()
            tick.move(to: point(c, fr * (major ? 0.76 : 0.85), a))
            tick.addLine(to: point(c, fr * 0.95, a))
            let tint: Color = f >= 0.8 ? dialRed : .white.opacity(major ? 0.95 : 0.5)
            context.stroke(tick, with: .color(tint), style: StrokeStyle(lineWidth: major ? s * 0.016 : s * 0.007, lineCap: .round))
            if major {
                context.draw(Text("\(i / 5)").font(.system(size: s * 0.085, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.92)),
                             at: point(c, fr * 0.61, a))
            }
        }
        drawNeedle(&context, centre: c, length: fr * 0.84, tail: fr * 0.16, width: s * 0.022, angle: angle(min(max(progress, 0), 1)), color: needle, glow: s * 0.02)
        drawHub(&context, centre: c, radius: s * 0.055)
    }

    private static func fuel(_ context: inout GraphicsContext, size: CGSize, needle: Color, progress: Double) {
        let r = min(size.width / 2, size.height * 0.78) * 0.95
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + r * 0.36)
        func shell(_ radius: Double, _ drop: Double) -> Path {
            var path = Path()
            path.addArc(center: c, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            path.addLine(to: CGPoint(x: c.x + radius, y: c.y + drop))
            path.addLine(to: CGPoint(x: c.x - radius, y: c.y + drop))
            path.closeSubpath()
            return path
        }
        context.fill(shell(r, r * 0.17), with: .conicGradient(chrome, center: c, angle: .degrees(-35)))
        let fr = r * 0.89
        context.fill(shell(fr, r * 0.11), with: .radialGradient(Gradient(colors: [Color(hex: 0x2A2F38), Color(hex: 0x08090C)]),
                                                                center: CGPoint(x: c.x, y: c.y - fr * 0.5), startRadius: 0, endRadius: fr * 1.2))

        func angle(_ f: Double) -> Double { (180 + 180 * f) * .pi / 180 }
        var low = Path()
        low.addArc(center: c, radius: fr * 0.885, startAngle: .radians(angle(0)), endAngle: .radians(angle(0.125)), clockwise: false)
        context.stroke(low, with: .color(dialRed.opacity(0.9)), lineWidth: fr * 0.07)
        for i in 0...8 {
            let f = Double(i) / 8, a = angle(f), major = i.isMultiple(of: 2)
            var tick = Path()
            tick.move(to: point(c, fr * (major ? 0.74 : 0.84), a))
            tick.addLine(to: point(c, fr * 0.95, a))
            context.stroke(tick, with: .color(f <= 0.125 ? dialRed : .white.opacity(major ? 0.95 : 0.55)),
                           style: StrokeStyle(lineWidth: major ? r * 0.035 : r * 0.016, lineCap: .round))
        }
        let font = Font.system(size: r * 0.17, weight: .bold, design: .rounded)
        context.draw(Text("E").font(font).foregroundColor(dialRed), at: point(c, fr * 0.56, angle(0)))
        context.draw(Text("½").font(font).foregroundColor(.white.opacity(0.9)), at: point(c, fr * 0.56, angle(0.5)))
        context.draw(Text("F").font(font).foregroundColor(.white.opacity(0.9)), at: point(c, fr * 0.56, angle(1)))
        var pump = context.resolve(Image(systemName: "fuelpump.fill"))
        pump.shading = .color(.white.opacity(0.7))
        let ps = r * 0.2
        context.draw(pump, in: CGRect(x: c.x - ps / 2, y: c.y - fr * 0.36 - ps / 2, width: ps, height: ps))

        drawNeedle(&context, centre: c, length: fr * 0.86, tail: fr * 0.1, width: r * 0.045, angle: angle(min(max(progress, 0), 1)), color: needle, glow: r * 0.04)
        drawHub(&context, centre: c, radius: r * 0.1)
    }

    /// Rev counter (Phase 19): thin dark bezel, black face, 0–8 with a wide red zone from 6,
    /// "×1000 r/min" under the hub and an orange glow ring behind the needle.
    private static func tachometer(_ context: inout GraphicsContext, size: CGSize, needle: Color, progress: Double) {
        let s = min(size.width, size.height)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = s * 0.48
        context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0x3A3F47), Color(hex: 0x0B0C0F)]),
                                           startPoint: CGPoint(x: c.x, y: c.y - r), endPoint: CGPoint(x: c.x, y: c.y + r)))
        let fr = r * 0.93
        let face = CGRect(x: c.x - fr, y: c.y - fr, width: fr * 2, height: fr * 2)
        context.fill(Path(ellipseIn: face), with: .radialGradient(Gradient(colors: [Color(hex: 0x1A1C21), Color(hex: 0x030304)]),
                                                                  center: c, startRadius: 0, endRadius: fr))
        let start = 135.0, sweep = 270.0
        func angle(_ f: Double) -> Double { (start + sweep * f) * .pi / 180 }
        let value = min(max(progress, 0), 1)
        // Glow ring up to the needle.
        var lit = Path()
        lit.addArc(center: c, radius: fr * 0.97, startAngle: .radians(angle(0)), endAngle: .radians(angle(value)), clockwise: false)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: needle.opacity(0.9), radius: s * 0.03))
            layer.stroke(lit, with: .color(needle.opacity(0.85)), style: StrokeStyle(lineWidth: fr * 0.035, lineCap: .round))
        }
        var redZone = Path()
        redZone.addArc(center: c, radius: fr * 0.86, startAngle: .radians(angle(0.75)), endAngle: .radians(angle(1)), clockwise: false)
        context.stroke(redZone, with: .color(dialRed), lineWidth: fr * 0.1)
        for i in 0...80 {
            let f = Double(i) / 80, a = angle(f), major = i % 10 == 0, half = i % 5 == 0
            var tick = Path()
            tick.move(to: point(c, fr * (major ? 0.72 : (half ? 0.8 : 0.85)), a))
            tick.addLine(to: point(c, fr * 0.91, a))
            let tint: Color = f >= 0.75 ? dialRed : .white.opacity(major ? 1 : 0.55)
            context.stroke(tick, with: .color(tint), style: StrokeStyle(lineWidth: major ? s * 0.018 : s * 0.006, lineCap: .round))
            if major {
                context.draw(Text("\(i / 10)").font(.system(size: s * 0.1, weight: .bold, design: .rounded)).foregroundColor(f >= 0.75 ? dialRed : .white),
                             at: point(c, fr * 0.56, a))
            }
        }
        context.draw(Text("×1000 r/min").font(.system(size: s * 0.05, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.55)),
                     at: CGPoint(x: c.x, y: c.y + fr * 0.32))
        drawNeedle(&context, centre: c, length: fr * 0.88, tail: fr * 0.18, width: s * 0.02, angle: angle(value), color: needle, glow: s * 0.03)
        drawHub(&context, centre: c, radius: s * 0.06)
    }

    private static func drawNeedle(_ context: inout GraphicsContext, centre c: CGPoint, length: Double, tail: Double, width: Double,
                                   angle a: Double, color: Color, glow: Double) {
        let perp = a + .pi / 2
        var needle = Path()
        needle.move(to: point(c, length, a))
        needle.addLine(to: point(c, width, perp))
        needle.addLine(to: point(c, tail, a + .pi))
        needle.addLine(to: point(c, width, perp + .pi))
        needle.closeSubpath()
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: color.opacity(0.75), radius: glow))
            layer.fill(needle, with: .color(color))
        }
    }

    private static func drawHub(_ context: inout GraphicsContext, centre c: CGPoint, radius: Double) {
        let rect = CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [Color(hex: 0x9CA3AF), Color(hex: 0x1F2329)]),
                                                                  startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.6)), lineWidth: 1)
    }
}

// MARK: - Odometer

/// A value on rolling-counter wheels: letters and digits each in a dark wheel, the last one in `accent`.
struct OdometerView: View {
    let value: ResolvedField
    let accent: Color

    private static func boxed(_ ch: Character) -> Bool { ch.isLetter || ch.isNumber || ch == "-" }

    var body: some View {
        GeometryReader { geo in
            Group {
                switch value.style {
                case .plain:
                    wheels(value.text.isEmpty ? "--" : value.text, size: geo.size)
                case .timer(let date):
                    wheel(Text(date, style: .timer), width: geo.size.width * 0.9, height: geo.size.height, last: false)
                case .countdown(let date):
                    wheel(Text.countdown(to: date), width: geo.size.width * 0.9, height: geo.size.height, last: false)
                case .relative(let date):
                    wheel(Text(date, style: .relative), width: geo.size.width * 0.9, height: geo.size.height, last: false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func wheels(_ text: String, size: CGSize) -> some View {
        let chars = Array(text.uppercased())
        let boxedCount = Double(chars.filter(Self.boxed).count)
        let others = Double(chars.count) - boxedCount
        let gap = max(size.height * 0.05, 1)
        let width = min(size.height * 0.68, (size.width - gap * Double(chars.count)) / max(boxedCount + others * 0.45, 1))
        let height = min(size.height, width * 1.5)
        let last = chars.lastIndex(where: Self.boxed)
        HStack(spacing: gap) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, ch in
                if Self.boxed(ch) {
                    wheel(Text(String(ch)), width: width, height: height, last: index == last)
                } else {
                    Text(String(ch))
                        .font(.system(size: height * 0.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: width * (ch == " " ? 0.25 : 0.45))
                }
            }
        }
    }

    private func wheel(_ text: Text, width: Double, height: Double, last: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: max(width * 0.12, 2), style: .continuous)
        let base = last ? accent : Color(hex: 0x2B2F37)
        return text
            .font(.system(size: height * 0.64, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .padding(.horizontal, width * 0.06)
            .frame(width: width, height: height)
            .background(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: base, location: 0.35),
                                               .init(color: base, location: 0.65), .init(color: .black, location: 1)],
                                       startPoint: .top, endPoint: .bottom))
            .overlay(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center))
            .clipShape(shape)
            .overlay(shape.stroke(.black.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
    }
}

// MARK: - Backgrounds

/// Soft, blurred colour blobs on a dark base.
struct FrostedBackground: View {
    let a: Color
    let b: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color(hex: 0x0B1020)
                Circle().fill(a).frame(width: h * 1.05, height: h * 1.05).position(x: w * 0.2, y: h * 0.18).blur(radius: h * 0.2)
                Circle().fill(b).frame(width: h, height: h).position(x: w * 0.84, y: h * 0.86).blur(radius: h * 0.2)
                Circle().fill(b.opacity(0.55)).frame(width: h * 0.55, height: h * 0.55).position(x: w * 0.62, y: h * 0.12).blur(radius: h * 0.16)
                Circle().fill(a.opacity(0.5)).frame(width: h * 0.5, height: h * 0.5).position(x: w * 0.3, y: h * 0.95).blur(radius: h * 0.16)
            }
        }
    }
}

/// A sky for the time of day: night with stars and a crescent moon, dawn and dusk with a low sun,
/// day with the sun on its arc and a couple of clouds. Hills along the bottom.
struct SkyBackground: View {
    let date: Date
    let sun: SunTimes

    var body: some View {
        let phase = Sky.phase(at: date, sun: sun)
        let progress = Sky.sunProgress(at: date, sun: sun)
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(colors: Self.colors(phase), startPoint: .top, endPoint: .bottom)
                switch phase {
                case .night:
                    NightSky()
                case .dawn, .dusk:
                    let x = phase == .dawn ? w * 0.22 : w * 0.78
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFFB45E).opacity(0.85), .clear], center: .center, startRadius: 0, endRadius: h * 0.55))
                        .frame(width: h * 1.1, height: h * 1.1)
                        .position(x: x, y: h * 0.82)
                    Circle().fill(Color(hex: 0xFFD98A)).frame(width: h * 0.28, height: h * 0.28).position(x: x, y: h * 0.84)
                case .day:
                    let x = w * (0.08 + 0.84 * progress)
                    let y = h * (0.78 - 0.6 * sin(.pi * progress))
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFFF6C8).opacity(0.9), Color(hex: 0xFFF6C8).opacity(0.25), .clear],
                                             center: .center, startRadius: 0, endRadius: h * 0.4))
                        .frame(width: h * 0.8, height: h * 0.8)
                        .position(x: x, y: y)
                    Circle().fill(Color(hex: 0xFFFBEA)).frame(width: h * 0.18, height: h * 0.18).position(x: x, y: y)
                    Cloud().frame(width: h * 0.5, height: h * 0.17).position(x: w * (progress < 0.5 ? 0.76 : 0.24), y: h * 0.12)
                    Cloud().frame(width: h * 0.32, height: h * 0.11).opacity(0.75).position(x: w * 0.52, y: h * 0.08)
                }
                Hills(dark: phase != .day)
            }
            .frame(width: w, height: h)
        }
    }

    static func colors(_ phase: SkyPhase) -> [Color] {
        switch phase {
        case .night: [Color(hex: 0x060A1C), Color(hex: 0x141D45), Color(hex: 0x24305E)]
        case .dawn: [Color(hex: 0x24305E), Color(hex: 0x8A5A8C), Color(hex: 0xF4A261)]
        case .day: [Color(hex: 0x1D66C9), Color(hex: 0x4C9DE6), Color(hex: 0xA8D6F4)]
        case .dusk: [Color(hex: 0x2A1B5C), Color(hex: 0xB4497A), Color(hex: 0xFF8C42)]
        }
    }
}

private struct NightSky: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x2545F4914F6CDD1D
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 11) / Double(1 << 53)
            }
            for _ in 0..<60 {
                let x = next() * size.width, y = next() * size.height * 0.75, d = 0.6 + next() * 1.6
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(.white.opacity(0.35 + next() * 0.6)))
            }
            let r = size.height * 0.1
            let moon = CGPoint(x: size.width * 0.8, y: size.height * 0.24)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: Color(hex: 0xFFF3C4).opacity(0.6), radius: r * 0.6))
                layer.fill(Path(ellipseIn: CGRect(x: moon.x - r, y: moon.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xFFF6D6)))
                layer.blendMode = .destinationOut
                layer.fill(Path(ellipseIn: CGRect(x: moon.x - r * 0.55, y: moon.y - r * 1.15, width: r * 2, height: r * 2)), with: .color(.black))
            }
        }
    }
}

private struct Cloud: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Capsule().frame(width: w, height: h * 0.55).position(x: w / 2, y: h * 0.72)
                Circle().frame(width: h * 0.75, height: h * 0.75).position(x: w * 0.36, y: h * 0.46)
                Circle().frame(width: h, height: h).position(x: w * 0.6, y: h * 0.42)
            }
            .foregroundStyle(.white.opacity(0.9))
            .blur(radius: h * 0.04)
        }
    }
}

private struct Hills: View {
    let dark: Bool

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var back = Path()
            back.move(to: CGPoint(x: 0, y: h))
            back.addLine(to: CGPoint(x: 0, y: h * 0.84))
            back.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.82), control: CGPoint(x: w * 0.22, y: h * 0.72))
            back.addQuadCurve(to: CGPoint(x: w, y: h * 0.8), control: CGPoint(x: w * 0.75, y: h * 0.7))
            back.addLine(to: CGPoint(x: w, y: h))
            back.closeSubpath()
            context.fill(back, with: .color(dark ? .black.opacity(0.4) : Color(hex: 0x2F6B4F).opacity(0.55)))
            var front = Path()
            front.move(to: CGPoint(x: 0, y: h))
            front.addLine(to: CGPoint(x: 0, y: h * 0.92))
            front.addQuadCurve(to: CGPoint(x: w, y: h * 0.9), control: CGPoint(x: w * 0.55, y: h * 0.8))
            front.addLine(to: CGPoint(x: w, y: h))
            front.closeSubpath()
            context.fill(front, with: .color(dark ? .black.opacity(0.6) : Color(hex: 0x1F4D38).opacity(0.75)))
        }
    }
}

// MARK: - Stickers

/// Stitched seam: a groove and a dashed thread, inset from the edge.
struct Stitching: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let m = min(size.width, size.height)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: m * 0.07, dy: m * 0.07)
            context.stroke(Path(roundedRect: rect.insetBy(dx: -m * 0.02, dy: -m * 0.02), cornerRadius: m * 0.12),
                           with: .color(.black.opacity(0.4)), lineWidth: max(m * 0.01, 0.8))
            let seam = Path(roundedRect: rect, cornerRadius: m * 0.1)
            context.stroke(seam.offsetBy(dx: 0, dy: max(m * 0.006, 0.6)), with: .color(.black.opacity(0.5)),
                           style: StrokeStyle(lineWidth: max(m * 0.014, 1), lineCap: .round, dash: [m * 0.035, m * 0.025]))
            context.stroke(seam, with: .color(color),
                           style: StrokeStyle(lineWidth: max(m * 0.014, 1), lineCap: .round, dash: [m * 0.035, m * 0.025]))
        }
    }
}

/// The white border of a road sign.
struct SignFrame: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let m = min(size.width, size.height)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: m * 0.06, dy: m * 0.06)
            context.stroke(Path(roundedRect: rect, cornerRadius: m * 0.07), with: .color(color), lineWidth: max(m * 0.028, 1))
        }
    }
}

/// A straight-ahead road-sign arrow.
struct RoadArrow: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let o = CGPoint(x: (size.width - s) / 2, y: (size.height - s) / 2)
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
            var arrow = Path()
            arrow.move(to: p(0.5, 0.04))
            arrow.addLine(to: p(0.9, 0.46))
            arrow.addLine(to: p(0.64, 0.46))
            arrow.addLine(to: p(0.64, 0.96))
            arrow.addLine(to: p(0.36, 0.96))
            arrow.addLine(to: p(0.36, 0.46))
            arrow.addLine(to: p(0.1, 0.46))
            arrow.closeSubpath()
            context.fill(arrow, with: .color(color))
        }
    }
}

/// Head-up display lines: a horizon with a pitch ladder, lane edges and centre dashes in perspective.
struct HUDLines: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let horizon = h * 0.46
            var line = Path()
            line.move(to: CGPoint(x: w * 0.04, y: horizon))
            line.addLine(to: CGPoint(x: w * 0.4, y: horizon))
            line.move(to: CGPoint(x: w * 0.6, y: horizon))
            line.addLine(to: CGPoint(x: w * 0.96, y: horizon))
            context.stroke(line, with: .color(color.opacity(0.55)), lineWidth: 1)
            for dy in [0.1, 0.2] {
                var ladder = Path()
                ladder.move(to: CGPoint(x: w * 0.42, y: horizon + h * dy))
                ladder.addLine(to: CGPoint(x: w * 0.47, y: horizon + h * dy))
                ladder.move(to: CGPoint(x: w * 0.53, y: horizon + h * dy))
                ladder.addLine(to: CGPoint(x: w * 0.58, y: horizon + h * dy))
                context.stroke(ladder, with: .color(color.opacity(0.35)), lineWidth: 1)
            }
            var lanes = Path()
            lanes.move(to: CGPoint(x: w * 0.06, y: h))
            lanes.addLine(to: CGPoint(x: w * 0.48, y: horizon + h * 0.03))
            lanes.move(to: CGPoint(x: w * 0.94, y: h))
            lanes.addLine(to: CGPoint(x: w * 0.52, y: horizon + h * 0.03))
            context.stroke(lanes, with: .linearGradient(Gradient(colors: [color.opacity(0.05), color.opacity(0.75)]),
                                                        startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)), lineWidth: 2)
            var f = 0.08
            while f < 1 {
                let length = 0.06 + f * 0.12
                var dash = Path()
                dash.move(to: CGPoint(x: w / 2, y: horizon + (h - horizon) * f))
                dash.addLine(to: CGPoint(x: w / 2, y: horizon + (h - horizon) * min(f + length, 1)))
                context.stroke(dash, with: .color(color.opacity(0.25 + 0.5 * f)), lineWidth: 1 + 3 * f)
                f += length * 2
            }
        }
    }
}

/// Ticket details on a paper background: notches at the tear line, the perforation and a barcode
/// on the stub. Wide frames get the full ticket (tear line at 70%); square ones the stub only.
struct TicketArt: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height, m = min(w, h)
            let px = w / max(h, 1) > 1.3 ? w * 0.705 : w * 0.2
            let r = m * 0.085
            for y in [0.0, h] {
                context.fill(Path(ellipseIn: CGRect(x: px - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
            }
            var perforation = Path()
            perforation.move(to: CGPoint(x: px, y: r * 1.5))
            perforation.addLine(to: CGPoint(x: px, y: h - r * 1.5))
            context.stroke(perforation, with: .color(color.opacity(0.3)),
                           style: StrokeStyle(lineWidth: max(m * 0.012, 1), lineCap: .round, dash: [m * 0.03, m * 0.03]))
            let pattern: [Double] = [1, 2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2, 1, 1, 3, 1]
            let x1 = w - m * 0.1
            var x = px + m * 0.12
            var i = 0
            while x < x1 {
                let bar = pattern[i % pattern.count] * m * 0.008
                if i.isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: x, y: h * 0.76, width: min(bar, x1 - x), height: h * 0.13)), with: .color(color.opacity(0.8)))
                }
                x += bar
                i += 1
            }
        }
    }
}

/// A frosted glass panel: a translucent fill, a top sheen and a light edge.
struct GlassPanel: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let m = min(geo.size.width, geo.size.height)
            let shape = RoundedRectangle(cornerRadius: m * 0.16, style: .continuous)
            shape.fill(color.opacity(0.14))
                .overlay(shape.fill(LinearGradient(colors: [color.opacity(0.16), .clear], startPoint: .top, endPoint: .center)))
                .overlay(shape.stroke(LinearGradient(colors: [color.opacity(0.6), color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                      lineWidth: max(m * 0.012, 0.8)))
        }
    }
}

/// Leather grain: speckles in a fixed pseudo-random pattern, with a soft sheen and darker edges.
enum LeatherGrain {
    static func draw(_ context: inout GraphicsContext, size: CGSize) {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        let cell = 4.0
        var y = 0.0
        while y < size.height {
            var x = 0.0
            while x < size.width {
                let dark = next() < 0.55
                let d = 1.1 + next() * 1.6
                let rect = CGRect(x: x + next() * cell, y: y + next() * cell, width: d, height: d * 0.8)
                context.fill(Path(ellipseIn: rect), with: .color(dark ? .black.opacity(0.22) : .white.opacity(0.045)))
                x += cell
            }
            y += cell
        }
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(0.08), .clear, .black.opacity(0.38)]),
                                           center: CGPoint(x: size.width * 0.4, y: size.height * 0.3), startRadius: 0,
                                           endRadius: max(size.width, size.height) * 0.8))
    }
}
