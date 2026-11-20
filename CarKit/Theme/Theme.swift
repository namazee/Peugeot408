import SwiftUI

/// The single place to tune the look of the app and every widget.
public enum Theme {
    /// Raw hex values (0xRRGGBB), from theme/tokens.json via the generated `ThemeTokens`
    /// (Remotion reads the same JSON, spec §7).
    public enum Hex {
        public static let accent: UInt32 = ThemeTokens.accent              // "Obsession Blue"-style accent
        public static let background: UInt32 = ThemeTokens.background      // near-black
        public static let surface: UInt32 = ThemeTokens.surface
        public static let primaryText: UInt32 = ThemeTokens.primaryText
        public static let secondaryText: UInt32 = ThemeTokens.secondaryText
        public static let dueSoon: UInt32 = ThemeTokens.dueSoon            // amber
        public static let overdue: UInt32 = ThemeTokens.overdue            // red
    }

    public static let accent = Color(hex: Hex.accent)
    public static let background = Color(hex: Hex.background)
    public static let surface = Color(hex: Hex.surface)
    public static let primaryText = Color(hex: Hex.primaryText)
    public static let secondaryText = Color(hex: Hex.secondaryText)
    public static let dueSoon = Color(hex: Hex.dueSoon)
    public static let overdue = Color(hex: Hex.overdue)

    /// SF Pro Rounded with monospaced digits, for big glanceable numbers.
    public static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// Short uppercase-style labels under a value.
    public static func label(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

public extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
