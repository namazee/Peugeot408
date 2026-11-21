import SwiftUI

// Drawn pieces for the Phase 18 templates (spec §4b Templates, §3 Panorama hero): shift lights,
// thermometer, battery, moon phase, cork, chalkboard and halftone, and their stickers. All original,
// drawn in code (ASSETS-LICENSES.md).

// MARK: - Calendar helpers

/// The moon's phase from the date: fraction of the synodic month since a known new moon (0 and 1 = new, 0.5 = full).
public enum MoonPhase {
    static let synodicMonth = 29.530588853
    /// New moon of 6 January 2000, 18:14 UTC.
    static let reference = Date(timeIntervalSince1970: 947_182_440)

    public static func fraction(at date: Date) -> Double {
        let days = date.timeIntervalSince(reference) / 86_400
        let f = days.truncatingRemainder(dividingBy: synodicMonth) / synodicMonth
        return f < 0 ? f + 1 : f
    }

    public static func name(at date: Date) -> String {
        let names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
                     "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        return names[Int((fraction(at: date) * 8).rounded()) % 8]
    }
}

public enum WordClock {
    private static let hours = ["TWELVE", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN"]

    /// The time in words to the nearest five minutes: "HALF PAST TEN", "TEN TO ELEVEN", "NINE O'CLOCK".
    public static func text(at date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        var hour = parts.hour ?? 0
        var minute = Int((Double(parts.minute ?? 0) / 5).rounded()) * 5
        if minute == 60 {
            minute = 0
            hour += 1
        }
        let this = hours[hour % 12], next = hours[(hour + 1) % 12]
        switch minute {
        case 0: return "\(this) O'CLOCK"
        case 5: return "FIVE PAST \(this)"
        case 10: return "TEN PAST \(this)"
        case 15: return "QUARTER PAST \(this)"
        case 20: return "TWENTY PAST \(this)"
        case 25: return "TWENTY-FIVE PAST \(this)"
        case 30: return "HALF PAST \(this)"
        case 35: return "TWENTY-FIVE TO \(next)"
        case 40: return "TWENTY TO \(next)"
        case 45: return "QUARTER TO \(next)"
        case 50: return "TEN TO \(next)"
        default: return "FIVE TO \(next)"
        }
    }

    /// When the words change: minute 3, 8, 13 … of each hour (the nearest five minutes rolls over there).
    public static func changeDates(from start: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        guard let minuteStart = calendar.dateInterval(of: .minute, for: start)?.start else { return [] }
        let minute = calendar.component(.minute, from: minuteStart)
        let ahead = ((3 - minute % 5) + 5) % 5
        let first = minuteStart.addingTimeInterval(Double(ahead == 0 ? 5 : ahead) * 60)
        return (0..<count).map { first.addingTimeInterval(Double($0) * 300) }.filter { $0 > start }
    }
}

public enum HijriDate {
    static let months = ["Muharam", "Safar", "Rabiulawal", "Rabiulakhir", "Jamadilawal", "Jamadilakhir",
                         "Rejab", "Syaaban", "Ramadan", "Syawal", "Zulkaedah", "Zulhijah"]

    /// "6 Jamadilakhir 1448", from the Umm al-Qura calendar (can differ by a day from JAKIM's date).
    public static func text(at date: Date, timeZone: TimeZone = .current) -> String {
        var islamic = Calendar(identifier: .islamicUmmAlQura)
        islamic.timeZone = timeZone
        let parts = islamic.dateComponents([.day, .month, .year], from: date)
        guard let day = parts.day, let month = parts.month, let year = parts.year, (1...12).contains(month) else { return "--" }
        return "\(day) \(months[month - 1]) \(year)"
    }
}

// MARK: - Layers

/// A row of shift-light LEDs: green, then amber, then red, lit up to `progress`.
struct ShiftLightsView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let count = 10
            let lit = Int((min(max(progress, 0), 1) * Double(count)).rounded())
            let gap = geo.size.width * 0.02
            let d = min(geo.size.height * 0.8, (geo.size.width - gap * Double(count + 1)) / Double(count))
            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { i in
                    let color = i < 4 ? Color(hex: 0x22E55E) : (i < 7 ? Color(hex: 0xFFB020) : Color(hex: 0xFF3B30))
                    let on = i < lit
                    Circle()
                        .fill(RadialGradient(colors: [on ? .white : color.opacity(0.35), on ? color : color.opacity(0.12)],
                                             center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: d * 0.6))
                        .overlay(Circle().stroke(.black.opacity(0.6), lineWidth: max(d * 0.06, 0.8)))
                        .shadow(color: on ? color.opacity(0.9) : .clear, radius: d * 0.35)
                        .frame(width: d, height: d)
                }
            }
            .padding(.horizontal, gap)
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Capsule().fill(Color(hex: 0x08090B)).overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1)))
        }
        .accessibilityHidden(true)
    }
}

/// A glass thermometer: the red column fills to `progress`.
struct ThermometerView: View {
    let progress: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = min(size.width, size.height * 0.32), h = size.height
            let cx = size.width / 2
            let bulb = w * 0.95
            let tube = w * 0.42
            let top = h * 0.04, bottom = h - bulb
            let tubeRect = CGRect(x: cx - tube / 2, y: top, width: tube, height: bottom - top + bulb / 2)
            let bulbRect = CGRect(x: cx - bulb / 2, y: h - bulb, width: bulb, height: bulb)
            var glass = Path(roundedRect: tubeRect, cornerRadius: tube / 2)
            glass.addEllipse(in: bulbRect)
            context.fill(glass, with: .color(.white.opacity(0.14)))
            let inset = tube * 0.22
            let fillTop = bottom - (bottom - top - inset) * min(max(progress, 0), 1)
            var mercury = Path(roundedRect: CGRect(x: cx - tube / 2 + inset, y: fillTop, width: tube - inset * 2, height: bottom - fillTop + bulb / 2),
                               cornerRadius: (tube - inset * 2) / 2)
            mercury.addEllipse(in: bulbRect.insetBy(dx: inset, dy: inset))
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(0.7), radius: tube * 0.3))
                layer.fill(mercury, with: .linearGradient(Gradient(colors: [color, color.opacity(0.75)]),
                                                          startPoint: CGPoint(x: cx - tube, y: 0), endPoint: CGPoint(x: cx + tube, y: 0)))
            }
            context.stroke(glass, with: .color(.white.opacity(0.75)), lineWidth: max(tube * 0.08, 1))
            var ticks = Path()
            for i in 0...10 {
                let y = bottom - (bottom - top - inset) * Double(i) / 10
                ticks.move(to: CGPoint(x: cx + tube / 2 + tube * 0.25, y: y))
                ticks.addLine(to: CGPoint(x: cx + tube / 2 + tube * (i.isMultiple(of: 5) ? 0.9 : 0.55), y: y))
            }
            context.stroke(ticks, with: .color(.white.opacity(0.7)), lineWidth: max(tube * 0.06, 0.7))
            context.fill(Path(roundedRect: CGRect(x: cx - tube * 0.3, y: top + tube * 0.4, width: tube * 0.14, height: (bottom - top) * 0.6), cornerRadius: tube * 0.07),
                         with: .color(.white.opacity(0.35)))
        }
        .accessibilityHidden(true)
    }
}

/// A battery whose five cells fill to `progress`: green, amber under 30%, red under 15%.
struct BatteryView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let nub = w * 0.06
            let shell = CGRect(x: 0, y: 0, width: w - nub, height: h)
            let value = min(max(progress, 0), 1)
            let color = value < 0.15 ? Color(hex: 0xFF3B30) : (value < 0.3 ? Color(hex: 0xFFB020) : Color(hex: 0x22C55E))
            let cells = 5
            let lit = Int((value * Double(cells)).rounded(.up))
            let pad = h * 0.1
            let gap = h * 0.05
            let cellWidth = (shell.width - pad * 2 - gap * Double(cells - 1)) / Double(cells)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: h * 0.16, style: .continuous)
                    .fill(Color(hex: 0x101317))
                    .overlay(RoundedRectangle(cornerRadius: h * 0.16, style: .continuous).stroke(Color(hex: 0xD5DAE1), lineWidth: max(h * 0.05, 1.5)))
                    .frame(width: shell.width, height: shell.height)
                RoundedRectangle(cornerRadius: nub * 0.4)
                    .fill(Color(hex: 0xD5DAE1))
                    .frame(width: nub, height: h * 0.36)
                    .offset(x: shell.width - nub * 0.15, y: h * 0.32)
                HStack(spacing: gap) {
                    ForEach(0..<cells, id: \.self) { i in
                        RoundedRectangle(cornerRadius: h * 0.06, style: .continuous)
                            .fill(i < lit ? color : Color.white.opacity(0.06))
                            .shadow(color: i < lit ? color.opacity(0.6) : .clear, radius: h * 0.06)
                            .frame(width: cellWidth, height: h - pad * 2)
                    }
                }
                .offset(x: pad, y: pad)
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }
}

/// The moon in its phase for `date`: the lit part bounded by the limb and the terminator ellipse.
struct MoonPhaseView: View {
    let date: Date
    let color: Color

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2 * 0.92
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(0.45), radius: r * 0.25))
                layer.fill(Path(ellipseIn: disc), with: .color(Color(hex: 0x2A2F3A)))
            }
            let f = MoonPhase.fraction(at: date)
            let waxing = f < 0.5
            let k = cos(f * 2 * .pi)          // 1 at new moon, −1 at full
            let rx = abs(k) * r
            let side: Double = waxing ? 1 : -1        // the lit limb is on the right while waxing
            let bulge: Double = (k > 0 ? 1 : -1) * side // crescent: the terminator bulges towards the lit limb
            var lit = Path()
            lit.move(to: CGPoint(x: c.x, y: c.y - r))
            for i in 0...40 {
                let a = -Double.pi / 2 + Double.pi * Double(i) / 40
                lit.addLine(to: CGPoint(x: c.x + side * r * cos(a), y: c.y + r * sin(a)))
            }
            for i in 0...40 {
                let a = Double.pi / 2 - Double.pi * Double(i) / 40
                lit.addLine(to: CGPoint(x: c.x + bulge * rx * cos(a), y: c.y + r * sin(a)))
            }
            lit.closeSubpath()
            context.fill(lit, with: .color(color))
            var random = SeededRandom(0x0A11)
            for _ in 0..<7 {
                let d = r * (0.08 + random.next() * 0.16)
                let x = c.x + (random.next() - 0.5) * r * 1.2, y = c.y + (random.next() - 0.5) * r * 1.2
                context.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)), with: .color(.black.opacity(0.08)))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Textures

enum CorkBoard {
    static func draw(_ context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(0xC0C0A)
        let count = Int(size.width * size.height / 9)
        for _ in 0..<min(count, 6_000) {
            let x = random.next() * size.width, y = random.next() * size.height
            let d = 0.8 + random.next() * 2.2
            let dark = random.next() < 0.6
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d * (0.6 + random.next() * 0.6))),
                         with: .color(dark ? Color(hex: 0x5A3A1A).opacity(0.35) : Color(hex: 0xF0D3A0).opacity(0.25)))
        }
        context.stroke(Path(CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)), with: .color(.black.opacity(0.25)), lineWidth: 4)
    }
}

enum Chalkboard {
    static func draw(_ context: inout GraphicsContext, size: CGSize) {
        var random = SeededRandom(0xC4A1C)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: size.height * 0.06))
            for _ in 0..<7 {
                let w = size.width * (0.2 + random.next() * 0.4), h = size.height * (0.08 + random.next() * 0.15)
                let rect = CGRect(x: random.next() * size.width - w / 3, y: random.next() * size.height, width: w, height: h)
                layer.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.06 + random.next() * 0.06)))
            }
        }
        for _ in 0..<500 {
            let x = random.next() * size.width, y = random.next() * size.height
            context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.08)))
        }
        let frame = CGRect(origin: .zero, size: size)
        context.stroke(Path(frame.insetBy(dx: 3, dy: 3)), with: .color(Color(hex: 0x7A4E2A)), lineWidth: 6)
        context.stroke(Path(frame.insetBy(dx: 6, dy: 6)), with: .color(.black.opacity(0.35)), lineWidth: 1.5)
    }
}

enum Halftone {
    static func draw(_ context: inout GraphicsContext, size: CGSize) {
        let cell = max(size.height / 18, 5)
        var y = 0.0
        var row = 0
        while y < size.height + cell {
            var x = row.isMultiple(of: 2) ? 0 : cell / 2
            while x < size.width + cell {
                let t = min(max((x / max(size.width, 1) + y / max(size.height, 1)) / 2, 0), 1)
                let d = cell * (0.15 + 0.7 * t)
                context.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)), with: .color(.black.opacity(0.16)))
                x += cell
            }
            y += cell * 0.87
            row += 1
        }
    }
}

// MARK: - Stickers

/// An instant-photo frame: white border with a deeper bottom margin, a dark window and a red pin.
struct PolaroidFrame: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, m = min(w, h)
            ZStack(alignment: .top) {
                Rectangle().fill(color)
                    .shadow(color: .black.opacity(0.45), radius: m * 0.04, x: m * 0.01, y: m * 0.025)
                Rectangle().fill(LinearGradient(colors: [Color(hex: 0x2B3240), Color(hex: 0x11141A)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.86, height: h * 0.68)
                    .padding(.top, w * 0.07)
                Circle().fill(RadialGradient(colors: [Color(hex: 0xFF6B6B), Color(hex: 0xB91C1C)], center: .init(x: 0.35, y: 0.35), startRadius: 0, endRadius: m * 0.05))
                    .frame(width: m * 0.09, height: m * 0.09)
                    .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1.5)
                    .offset(y: -m * 0.03)
            }
        }
    }
}

/// A sticky note with a slight curl shadow and a strip of tape.
struct StickyNote: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, m = min(w, h)
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(LinearGradient(colors: [color, color.opacity(0.88)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.4), radius: m * 0.035, x: m * 0.015, y: m * 0.03)
                Rectangle().fill(.white.opacity(0.45))
                    .frame(width: w * 0.36, height: m * 0.1)
                    .rotationEffect(.degrees(-3))
                    .offset(y: -m * 0.04)
            }
        }
    }
}

/// An LED board: black panel with a fine grid of unlit dots.
struct DotMatrixPanel: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let r = min(size.width, size.height) * 0.08
            context.fill(Path(roundedRect: rect, cornerRadius: r), with: .color(Color(hex: 0x060606)))
            let pitch = max(size.height / 16, 3)
            var y = pitch / 2
            while y < size.height {
                var x = pitch / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - pitch * 0.28, y: y - pitch * 0.28, width: pitch * 0.56, height: pitch * 0.56)),
                                 with: .color(color.opacity(0.1)))
                    x += pitch
                }
                y += pitch
            }
            context.stroke(Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: r), with: .color(Color(hex: 0x3A3F47)), lineWidth: 2)
        }
    }
}

/// A round road sign: white disc with a ring in the layer colour.
struct SpeedSign: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(Color(hex: 0xBFC5CC))
                Circle().fill(.white).padding(s * 0.025)
                Circle().stroke(color, lineWidth: s * 0.11).padding(s * 0.08)
            }
            .shadow(color: .black.opacity(0.35), radius: s * 0.03, y: s * 0.02)
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A faint grid of capital letters (behind the word clock).
struct LetterGrid: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let letters = Array("ITLISASAMPMACQUARTERDCTWENTYFIVEXHALFSTENFTOPASTERUNINEONESIXTHREEFOURFIVETWOEIGHTELEVENSEVENTWELVETENSEOCLOCK")
            let rows = 8, columns = 14
            let cw = size.width / Double(columns), rh = size.height / Double(rows)
            var i = 0
            for row in 0..<rows {
                for column in 0..<columns {
                    let ch = String(letters[i % letters.count])
                    i += 1
                    let text = Text(ch).font(.system(size: rh * 0.55, weight: .semibold, design: .monospaced)).foregroundStyle(color.opacity(0.13))
                    context.draw(text, at: CGPoint(x: cw * (Double(column) + 0.5), y: rh * (Double(row) + 0.5)))
                }
            }
        }
    }
}

/// A vinyl record: grooves, a sheen, a coloured centre label and the spindle hole.
struct VinylRecord: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            func circle(_ r: Double) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.6), radius: s * 0.03, y: s * 0.015))
                layer.fill(circle(s / 2), with: .color(Color(hex: 0x0C0C0E)))
            }
            var r = s * 0.48
            while r > s * 0.19 {
                context.stroke(circle(r), with: .color(.white.opacity(0.05)), lineWidth: 0.6)
                r -= s * 0.012
            }
            context.fill(circle(s / 2), with: .conicGradient(Gradient(colors: [.clear, .white.opacity(0.14), .clear, .clear, .white.opacity(0.1), .clear]),
                                                             center: c, angle: .degrees(-30)))
            context.fill(circle(s * 0.17), with: .color(color))
            context.stroke(circle(s * 0.12), with: .color(.white.opacity(0.35)), lineWidth: 0.8)
            context.fill(circle(s * 0.018), with: .color(Color(hex: 0x0C0C0E)))
        }
    }
}

/// A comic burst: a jagged star in the layer colour with a black outline.
struct ComicBurst: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            var burst = Path()
            let points = 18
            var random = SeededRandom(0xB00F)
            for i in 0..<(points * 2) {
                let a = Double(i) / Double(points * 2) * 2 * .pi - .pi / 2
                let outer = i.isMultiple(of: 2)
                let k = outer ? 0.96 - random.next() * 0.08 : 0.74 - random.next() * 0.06
                let p = CGPoint(x: c.x + cos(a) * size.width / 2 * k, y: c.y + sin(a) * size.height / 2 * k)
                if i == 0 { burst.move(to: p) } else { burst.addLine(to: p) }
            }
            burst.closeSubpath()
            context.fill(burst.offsetBy(dx: 3, dy: 3), with: .color(.black))
            context.fill(burst, with: .color(color))
            context.stroke(burst, with: .color(.black), style: StrokeStyle(lineWidth: max(min(size.width, size.height) * 0.025, 1.5), lineJoin: .round))
        }
    }
}

/// A light cone falling from the top: bright at the lamp, fading to the floor.
struct LightCone: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            var cone = Path()
            cone.move(to: CGPoint(x: w * 0.42, y: 0))
            cone.addLine(to: CGPoint(x: w * 0.58, y: 0))
            cone.addLine(to: CGPoint(x: w, y: h))
            cone.addLine(to: CGPoint(x: 0, y: h))
            cone.closeSubpath()
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: w * 0.04))
                layer.fill(cone, with: .linearGradient(Gradient(colors: [color.opacity(0.7), color.opacity(0.08)]),
                                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            }
            context.fill(Path(ellipseIn: CGRect(x: w * 0.1, y: h * 0.86, width: w * 0.8, height: h * 0.14)), with: .color(color.opacity(0.18)))
            context.fill(Path(roundedRect: CGRect(x: w * 0.4, y: 0, width: w * 0.2, height: h * 0.03), cornerRadius: 2), with: .color(.white.opacity(0.9)))
        }
    }
}

/// Two palm-tree silhouettes leaning in from the sides.
struct Palms: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            func palm(base: CGPoint, top: CGPoint, scale: Double) {
                var trunk = Path()
                trunk.move(to: base)
                trunk.addQuadCurve(to: top, control: CGPoint(x: (base.x + top.x) / 2 + (top.x - base.x) * 0.3, y: (base.y + top.y) / 2))
                context.stroke(trunk, with: .color(color), style: StrokeStyle(lineWidth: scale * 0.05, lineCap: .round))
                for i in 0..<7 {
                    let a = -Double.pi + Double(i) / 6 * Double.pi
                    let end = CGPoint(x: top.x + cos(a) * scale * 0.42, y: top.y + sin(a) * scale * 0.18 + scale * 0.12)
                    var leaf = Path()
                    leaf.move(to: top)
                    leaf.addQuadCurve(to: end, control: CGPoint(x: (top.x + end.x) / 2, y: top.y - scale * 0.1))
                    context.stroke(leaf, with: .color(color), style: StrokeStyle(lineWidth: scale * 0.045, lineCap: .round))
                }
            }
            let h = size.height
            palm(base: CGPoint(x: size.width * 0.06, y: h), top: CGPoint(x: size.width * 0.12, y: h * 0.25), scale: h)
            palm(base: CGPoint(x: size.width * 0.95, y: h), top: CGPoint(x: size.width * 0.86, y: h * 0.35), scale: h * 0.85)
        }
    }
}

/// A sea with rolling wave lines, lit in the layer colour.
struct Waves: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Color(hex: 0x1D4E89), Color(hex: 0x0B1E3A)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            context.fill(Path(CGRect(x: w * 0.3, y: 0, width: w * 0.4, height: h)),
                         with: .linearGradient(Gradient(colors: [color.opacity(0.55), .clear]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.8)))
            for i in 0..<7 {
                let y = h * (0.12 + Double(i) * 0.13)
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: y))
                var x = 0.0
                while x <= w {
                    wave.addLine(to: CGPoint(x: x, y: y + sin(x / max(w, 1) * .pi * 10 + Double(i)) * h * 0.02))
                    x += 3
                }
                context.stroke(wave, with: .color(.white.opacity(0.12 + Double(i) * 0.03)), lineWidth: 1 + Double(i) * 0.3)
            }
        }
    }
}

/// Three layered mountain ridges with mist between them.
struct Mountains: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let ridges: [(Double, Double, UInt64)] = [(0.15, 0.35, 0x111), (0.4, 0.6, 0x222), (0.62, 0.9, 0x333)]
            for (index, ridge) in ridges.enumerated() {
                var random = SeededRandom(ridge.2)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: h))
                var x = 0.0
                path.addLine(to: CGPoint(x: 0, y: h * (ridge.0 + random.next() * 0.2)))
                while x < w {
                    x += w * (0.06 + random.next() * 0.08)
                    path.addLine(to: CGPoint(x: min(x, w), y: h * (ridge.0 + random.next() * (ridge.1 - ridge.0))))
                }
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
                let shade = 0.45 + Double(index) * 0.25
                context.fill(path, with: .color(color.opacity(shade)))
                context.fill(Path(CGRect(x: 0, y: h * (ridge.1 - 0.05), width: w, height: h * 0.12)),
                             with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.12), .clear]),
                                                   startPoint: CGPoint(x: 0, y: h * (ridge.1 - 0.05)), endPoint: CGPoint(x: 0, y: h * (ridge.1 + 0.07))))
            }
        }
    }
}

/// Five red start lights in a dark housing.
struct StartLights: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let d = min(h * 0.7, w / 6.5)
            HStack(spacing: d * 0.25) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(RadialGradient(colors: [.white, color], center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: d * 0.6))
                        .shadow(color: color.opacity(0.9), radius: d * 0.3)
                        .frame(width: d, height: d)
                }
            }
            .padding(.horizontal, d * 0.3)
            .padding(.vertical, d * 0.15)
            .background(RoundedRectangle(cornerRadius: d * 0.3).fill(Color(hex: 0x0A0B0D)).overlay(RoundedRectangle(cornerRadius: d * 0.3).stroke(.white.opacity(0.15))))
            .frame(width: w, height: h)
        }
    }
}

/// A two-row chequered strip.
struct ChequeredStrip: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let cell = size.height / 2
            var x = 0.0
            var column = 0
            while x < size.width {
                for row in 0..<2 where (column + row).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: x, y: Double(row) * cell, width: cell, height: cell)), with: .color(color))
                }
                x += cell
                column += 1
            }
        }
    }
}
