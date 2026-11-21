import SwiftUI
import UIKit
import WidgetKit

/// Draws a Studio design. Used by the builder, the gallery, the Slots screen and the widget, so
/// the car shows exactly what the app shows.
public struct DesignView: View {
    private let card: StudioCard
    private let showsBackground: Bool

    /// `showsBackground: false` when the widget draws the background as its container background.
    public init(card: StudioCard, showsBackground: Bool = true) {
        self.card = card
        self.showsBackground = showsBackground
    }

    public var body: some View {
        GeometryReader { geo in
            let scale = geo.size.height / DesignCanvas.referenceHeight
            ZStack {
                if showsBackground {
                    DesignBackgroundView(background: card.design.background, card: card)
                }
                ForEach(card.design.layers) { layer in
                    LayerView(layer: layer, card: card, scale: scale)
                        .frame(width: max(layer.width * geo.size.width, 1), height: max(layer.height * geo.size.height, 1))
                        .rotationEffect(.degrees(layer.rotation))
                        .opacity(layer.opacity)
                        .shadow(color: layer.shadow ? .black.opacity(0.6) : .clear, radius: 3 * scale, y: 1.5 * scale)
                        .modifier(NeonGlow(isOn: layer.glow == true, color: Color(hex: layer.colorHex), scale: scale))
                        .position(x: layer.x * geo.size.width, y: layer.y * geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let texts = card.design.layers.compactMap { layer -> String? in
            switch layer.content {
            case .text(let text): text
            case .plate(let text): text.isEmpty ? card.plateText : text
            case .data(let field): "\(field.displayName): \(card.values[field]?.text ?? "")"
            default: nil
            }
        }
        return ([card.design.name] + texts).joined(separator: ", ")
    }
}

/// One column of the Panorama hero: the whole design drawn at panorama width, shifted so this
/// slot shows its third (the gaps between columns fall between the slices).
public struct PanoramaSlice: View {
    private let card: StudioCard
    private let part: Int

    public init(card: StudioCard, part: Int) {
        self.card = card
        self.part = min(max(part, 0), PanoramaGeometry.columns - 1)
    }

    public var body: some View {
        GeometryReader { geo in
            let full = geo.size.width * PanoramaGeometry.widthInColumns
            DesignView(card: card)
                .frame(width: full, height: geo.size.height)
                .offset(x: -full * PanoramaGeometry.partStart(part))
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.design.name), part \(part + 1) of \(PanoramaGeometry.columns)")
    }
}

public struct DesignBackgroundView: View {
    let background: DesignBackground
    let card: StudioCard?

    public init(background: DesignBackground, card: StudioCard?) {
        self.background = background
        self.card = card
    }

    public var body: some View {
        switch background {
        case .solid(let hex):
            Color(hex: hex)
        case .gradient(let a, let b):
            LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .texture(let texture, let hex):
            TextureView(texture: texture, base: Color(hex: hex))
        case .photo(let file):
            if let path = card?.photoPath(file), let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom))
            } else {
                Theme.surface
            }
        case .aurora(let a, let b, let c):
            ZStack {
                LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(hex: c).opacity(0.9), .clear], center: .bottomLeading, startRadius: 0, endRadius: 220)
                RadialGradient(colors: [Color(hex: a).opacity(0.55), .clear], center: .topTrailing, startRadius: 0, endRadius: 160)
            }
        case .spotlight(let centre, let edge):
            RadialGradient(colors: [Color(hex: centre), Color(hex: edge)], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 4, endRadius: 190)
        case .stateColor(let base):
            let hex = card?.stateHex ?? base
            LinearGradient(colors: [Color(hex: ColorMath.mix(hex, 0xFFFFFF, amount: 0.12)), Color(hex: ColorMath.mix(hex, 0x000000, amount: 0.28))],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

/// Neon glow: two soft halos in the layer's own colour.
private struct NeonGlow: ViewModifier {
    let isOn: Bool
    let color: Color
    let scale: Double

    func body(content: Content) -> some View {
        if isOn {
            content
                .shadow(color: color.opacity(0.85), radius: 4 * scale)
                .shadow(color: color.opacity(0.55), radius: 12 * scale)
        } else {
            content
        }
    }
}

private struct LayerView: View {
    let layer: DesignLayer
    let card: StudioCard
    let scale: Double

    private var color: Color { Color(hex: layer.colorHex) }

    var body: some View {
        switch layer.content {
        case .text(let text):
            styled(Text(text))
        case .plate(let text):
            let plate = text.isEmpty ? card.plateText : text
            Text(plate.isEmpty ? "ABC 1234" : plate.uppercased())
                .font(card.plateFont.font(size: layer.fontSize * scale))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 6 * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 4 * scale).fill(.black))
                .overlay(RoundedRectangle(cornerRadius: 4 * scale).stroke(.white.opacity(0.8), lineWidth: 1.5 * scale))
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .widgetAccentable()
        case .sticker(let kind):
            ArtworkView(kind: kind, color: color)
        case .carPhoto:
            if let path = card.carPhotoPath, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
            } else {
                Image(systemName: "car.side.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color.opacity(0.8))
            }
        case .data(let field):
            dataText(field)
        case .gauge(let field):
            ArtworkView(kind: .gaugeArc, color: color, progress: field.flatMap { card.values[$0]?.progress } ?? 1)
        case .ring(let field):
            ProgressRing(color: color, progress: field.flatMap { card.values[$0]?.progress } ?? 1)
                .widgetAccentable()
        case .progressBar(let field):
            ProgressBar(color: color, progress: field.flatMap { card.values[$0]?.progress } ?? 1)
                .widgetAccentable()
        case .analogClock:
            AnalogClock(date: card.date, color: color)
        case .seasonalArt(let occasion):
            if let image = UIImage(named: occasion.artResource) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
            } else {
                ArtworkView(kind: occasion.fallbackArt, color: color)
            }
        }
    }

    @ViewBuilder
    private func dataText(_ field: DataField) -> some View {
        let value = card.values[field] ?? ResolvedField(text: "--")
        VStack(alignment: horizontal, spacing: 0) {
            if let caption = layer.caption, !caption.isEmpty {
                Text(caption.uppercased())
                    .font(.system(size: max(layer.fontSize * 0.36, 9) * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(0.7))
                    .lineLimit(1)
            }
            switch value.style {
            case .plain:
                styled(Text(value.text)).widgetAccentable()
            case .timer(let date):
                styled(Text(date, style: .timer)).monospacedDigit().widgetAccentable()
            case .countdown(let date):
                styled(Text.countdown(to: date)).monospacedDigit().widgetAccentable()
            case .relative(let date):
                styled(Text("\(Text(date, style: .relative)) ago"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    private func styled(_ text: Text) -> some View {
        text
            .font(font)
            .foregroundStyle(color)
            .multilineTextAlignment(textAlignment)
            .lineLimit(2)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    private var font: Font {
        let size = layer.fontSize * scale
        let weight: Font.Weight = switch layer.weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
        return switch layer.font {
        case .system: .system(size: size, weight: weight)
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        case .serif: .system(size: size, weight: weight, design: .serif)
        case .mono: .system(size: size, weight: weight, design: .monospaced)
        case .orbitron: .custom("Orbitron", size: size).weight(weight)
        case .playfair: .custom("Playfair Display", size: size).weight(weight)
        case .rajdhani: .custom("Rajdhani", size: size).weight(weight)
        }
    }

    private var textAlignment: TextAlignment {
        switch layer.alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var horizontal: HorizontalAlignment {
        switch layer.alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch layer.alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

/// A full ring with a track, filled clockwise from the top.
private struct ProgressRing: View {
    let color: Color
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(color.opacity(0.22), lineWidth: s * 0.085)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: s * 0.085, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(s * 0.05)
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A rounded bar with a track.
private struct ProgressBar: View {
    let color: Color
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            let h = min(geo.size.height, 14)
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.25))
                Capsule().fill(color).frame(width: max(h, geo.size.width * min(max(progress, 0), 1)))
            }
            .frame(height: h)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Analogue clock face; the timeline has an entry every minute while it's shown.
private struct AnalogClock: View {
    let date: Date
    let color: Color

    var body: some View {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = Double((parts.hour ?? 0) % 12 * 60 + (parts.minute ?? 0))
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(color.opacity(0.35), lineWidth: s * 0.03)
                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(color.opacity(i % 3 == 0 ? 0.9 : 0.45))
                        .frame(width: s * (i % 3 == 0 ? 0.035 : 0.02), height: s * 0.08)
                        .offset(y: -s * 0.41)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
                hand(length: 0.26, width: 0.05, angle: minutes / 720 * 360, size: s)
                hand(length: 0.38, width: 0.03, angle: (minutes.truncatingRemainder(dividingBy: 60)) / 60 * 360, size: s)
                Circle().fill(Theme.accent).frame(width: s * 0.07, height: s * 0.07)
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .widgetAccentable()
    }

    private func hand(length: Double, width: Double, angle: Double, size s: Double) -> some View {
        Capsule()
            .fill(color)
            .frame(width: s * width, height: s * length)
            .offset(y: -s * length / 2)
            .rotationEffect(.degrees(angle))
    }
}

public extension PlateFont {
    /// SwiftUI font for plate text.
    func font(size: CGFloat) -> Font {
        switch self {
        case .classic: .system(size: size, weight: .heavy)
        case .condensed: .system(size: size, weight: .bold).width(.condensed)
        case .mono: .system(size: size, weight: .bold, design: .monospaced)
        case .rounded: .system(size: size, weight: .heavy, design: .rounded)
        case .orbitron: .custom("Orbitron", size: size).weight(.heavy)
        case .rajdhani: .custom("Rajdhani", size: size).weight(.bold)
        }
    }
}
