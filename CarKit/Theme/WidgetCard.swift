import SwiftUI
import WidgetKit

/// Background treatments shared by every widget so they read as one family.
public enum CardStyle: Sendable {
    /// The look's normal tile (Bold: full colour; Neon: near-black with a glow).
    case standard
    /// Solid accent gradient, for emphasis (and the slot "flash" test).
    case accentFill
}

/// The card background, usable both inside widgets and in the app's previews. Draws the current
/// `cardLook`. In tinted / clear (Liquid Glass) rendering it steps aside so the system material shows through.
public struct WidgetCardBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.cardLook) private var look
    private let style: CardStyle
    private let paint: CardPaint

    public init(style: CardStyle = .standard, paint: CardPaint = .plain) {
        self.style = style
        self.paint = paint
    }

    public var body: some View {
        if renderingMode == .fullColor {
            switch style {
            case .standard:
                switch look {
                case .bold: BoldBackground(color: paint.color(.bold))
                case .neon: NeonBackground(glow: paint.color(.neon))
                }
            case .accentFill:
                let tint = look == .neon ? paint.color(.neon) : Theme.accent
                LinearGradient(
                    colors: [tint, tint.mix(with: Theme.background, by: 0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            Color.clear
        }
    }
}

/// Bold: a full-colour gradient with a soft sheen and a fine dot texture.
struct BoldBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [color.mix(with: .white, by: 0.14), color.mix(with: .black, by: 0.38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 150)
            TextureView(texture: .dots, base: .clear).opacity(0.35).blendMode(.overlay)
        }
    }
}

/// Neon: near-black with two soft pools of the glow colour.
struct NeonBackground: View {
    let glow: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0D1018), Color(hex: 0x030407)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [glow.opacity(0.34), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 160)
            RadialGradient(colors: [glow.opacity(0.14), .clear], center: .topLeading, startRadius: 0, endRadius: 120)
        }
    }
}

/// Wraps widget content with the shared background via `containerBackground(for: .widget)`.
public struct WidgetCard<Content: View>: View {
    private let style: CardStyle
    private let paint: CardPaint
    private let content: Content

    public init(style: CardStyle = .standard, paint: CardPaint = .plain, @ViewBuilder content: () -> Content) {
        self.style = style
        self.paint = paint
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) {
                WidgetCardBackground(style: style, paint: paint)
            }
    }
}
