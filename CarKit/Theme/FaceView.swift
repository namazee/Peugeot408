import SwiftUI
import WidgetKit

/// Draws a `CardFace` in the current look (spec §3 "Widget styles").
/// Bold: white on the full-colour tile, one huge centred number, a progress bar.
/// Neon: a glowing ring or gauge around a glowing number.
public struct FaceView: View {
    @Environment(\.cardLook) private var look
    @Environment(\.widgetRenderingMode) private var renderingMode
    let face: CardFace
    let paint: CardPaint
    let isMedium: Bool

    public init(face: CardFace, paint: CardPaint, isMedium: Bool = false) {
        self.face = face
        self.paint = paint
        self.isMedium = isMedium
    }

    private var accent: Color { look == .neon ? paint.color(.neon) : .white }
    private var soft: Color { look == .neon ? Theme.secondaryText : .white.opacity(0.82) }

    public var body: some View {
        if isMedium {
            HStack(spacing: 14) {
                main.frame(maxWidth: .infinity, maxHeight: .infinity)
                if !face.rows.isEmpty {
                    rows.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        } else {
            main
        }
    }

    // MARK: Main block

    @ViewBuilder
    private var main: some View {
        switch look {
        case .bold: boldMain
        case .neon: neonMain
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: face.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(accent)
                .widgetAccentable()
                .neonGlow(look == .neon ? accent : nil, radius: 4)
            Text(face.label.uppercased())
                .font(Theme.label(12))
                .tracking(0.6)
                .foregroundStyle(soft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
    }

    private var boldMain: some View {
        VStack(spacing: 2) {
            header
            Spacer(minLength: 0)
            bigValue(size: isMedium ? 46 : 42, color: .white)
            if let detail = face.detail {
                Text(detail)
                    .font(Theme.label(13))
                    .foregroundStyle(soft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            if let progress = face.progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.28))
                        Capsule().fill(.white).frame(width: max(5, geo.size.width * progress))
                    }
                }
                .frame(height: 5)
                .widgetAccentable()
            }
        }
    }

    @ViewBuilder
    private var neonMain: some View {
        if let progress = face.progress {
            VStack(spacing: 4) {
                header
                ZStack {
                    MeterView(meter: face.meter, progress: progress, color: accent)
                    VStack(spacing: 0) {
                        bigValue(size: isMedium ? 30 : 26, color: .white)
                            .padding(.horizontal, 16)
                    }
                    .offset(y: face.meter == .gauge ? 4 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                header
                Spacer(minLength: 0)
                bigValue(size: isMedium ? 44 : 38, color: .white, alignment: .leading)
                if let detail = face.detail {
                    Text(detail)
                        .font(Theme.label(13))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Rectangle()
                    .fill(accent)
                    .frame(width: 34, height: 3)
                    .clipShape(Capsule())
                    .neonGlow(accent, radius: 4)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    /// The huge number plus its unit, on one baseline.
    private func bigValue(size: CGFloat, color: Color, alignment: Alignment = .center) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            valueText
                .font(Theme.number(size, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .widgetAccentable()
                .neonGlow(look == .neon && renderingMode == .fullColor ? accent : nil, radius: 6)
            if let unit = face.unit {
                Text(unit)
                    .font(Theme.label(size * 0.36))
                    .foregroundStyle(look == .neon ? accent : soft)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var valueText: Text {
        switch face.value {
        case .text(let text): Text(text)
        case .timer(let date): Text.countdown(to: date)
        case .relative(let date): Text(date, style: .relative)
        }
    }

    // MARK: Medium rows

    private var rows: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(face.rows.prefix(5).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    Circle()
                        .fill(rowColor(row))
                        .frame(width: 7, height: 7)
                        .neonGlow(look == .neon ? rowColor(row) : nil, radius: 3)
                    Text(row.name)
                        .font(.system(size: 14, weight: row.isCurrent ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(row.isCurrent ? accent : soft)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(row.value)
                        .font(Theme.number(14, weight: .bold))
                        .foregroundStyle(row.isCurrent ? accent : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    private func rowColor(_ row: CardFace.Row) -> Color {
        if row.urgency != .ok { return row.urgency.color() }
        return row.isCurrent ? accent : (look == .neon ? accent.opacity(0.45) : .white.opacity(0.6))
    }
}

/// A glowing ring (how much is left) or a 240° gauge.
struct MeterView: View {
    let meter: CardFace.Meter
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let line = max(s * 0.075, 4)
            ZStack {
                switch meter {
                case .ring:
                    Circle().stroke(color.opacity(0.18), lineWidth: line)
                    Circle()
                        .trim(from: 0, to: max(progress, 0.005))
                        .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .neonGlow(color, radius: 5)
                case .gauge:
                    Group {
                        Circle().trim(from: 0, to: 2.0 / 3.0)
                            .stroke(color.opacity(0.18), style: StrokeStyle(lineWidth: line, lineCap: .round))
                        Circle().trim(from: 0, to: 2.0 / 3.0 * max(progress, 0.005))
                            .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                            .neonGlow(color, radius: 5)
                        ForEach(0..<9, id: \.self) { i in
                            Capsule()
                                .fill(color.opacity(0.5))
                                .frame(width: 1.5, height: line * 0.7)
                                .offset(y: -(s / 2 - line * 1.9))
                                // Trim angles run clockwise from 3 o'clock; the capsule points to 12.
                                .rotationEffect(.degrees(Double(i) * 30 + 90))
                        }
                    }
                    .rotationEffect(.degrees(150))
                }
            }
            .frame(width: s - line, height: s - line)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Two soft halos in `color` (nil = none). Only meant for the Neon look.
    @ViewBuilder
    func neonGlow(_ color: Color?, radius: CGFloat) -> some View {
        if let color {
            self
                .shadow(color: color.opacity(0.9), radius: radius * 0.5)
                .shadow(color: color.opacity(0.6), radius: radius * 1.6)
        } else {
            self
        }
    }
}
