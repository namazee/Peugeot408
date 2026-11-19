import SwiftUI
import WidgetKit

/// Background treatments shared by every widget so they read as one family.
public enum CardStyle: Sendable {
    /// Near-black with a soft accent glow.
    case standard
    /// Solid accent gradient, for emphasis (and the slot "flash" test).
    case accentFill
}

/// The card background, usable both inside widgets and in the app's mock CarPlay screen.
/// In tinted / clear (Liquid Glass) rendering it steps aside so the system material shows through.
public struct WidgetCardBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    private let style: CardStyle
    private let tint: Color

    public init(style: CardStyle = .standard, tint: Color = Theme.accent) {
        self.style = style
        self.tint = tint
    }

    public var body: some View {
        if renderingMode == .fullColor {
            switch style {
            case .standard:
                ZStack {
                    LinearGradient(
                        colors: [Theme.surface, Theme.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [tint.opacity(0.45), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 140
                    )
                }
            case .accentFill:
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

/// Wraps widget content with the shared background via `containerBackground(for: .widget)`.
public struct WidgetCard<Content: View>: View {
    private let style: CardStyle
    private let tint: Color
    private let content: Content

    public init(style: CardStyle = .standard, tint: Color = Theme.accent, @ViewBuilder content: () -> Content) {
        self.style = style
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) {
                WidgetCardBackground(style: style, tint: tint)
            }
    }
}
