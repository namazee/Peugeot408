import SwiftUI

/// The single place to tune the look of the app and every widget.
public enum Theme {
    /// Raw hex values (0xRRGGBB). Phase 8 exports these to a shared JSON file for Remotion.
    public enum Hex {
        public static let accent: UInt32 = 0x1F4FD8        // "Obsession Blue"-style accent
        public static let background: UInt32 = 0x0A0B0F    // near-black
        public static let surface: UInt32 = 0x161922
        public static let primaryText: UInt32 = 0xFFFFFF
        public static let secondaryText: UInt32 = 0x9AA1AD
        public static let dueSoon: UInt32 = 0xF5A524       // amber
        public static let overdue: UInt32 = 0xE5484D       // red
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
