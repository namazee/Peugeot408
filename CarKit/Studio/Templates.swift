import Foundation

/// The ready-made styles in the template gallery (spec §4b).
public enum TemplateStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case sporty
    case minimal
    case premium
    case dashboard
    case photo
    case clockAnalog
    case clockDigital
    case countdown
    case anniversary
    case myCar
    case boldTile
    case neonRing
    case twinGauges
    case aurora
    case sunsetDrive
    case nightDrive
    case showroom
    case racingStripes
    case starryNight
    case bigDate
    case yearProgress
    case retroLED

    public var id: String { rawValue }

    /// Gallery section.
    public var group: TemplateGroup {
        switch self {
        case .sporty, .minimal, .premium, .dashboard, .boldTile, .neonRing, .twinGauges, .aurora, .racingStripes: .data
        case .myCar, .photo, .nightDrive, .showroom, .sunsetDrive: .car
        case .clockAnalog, .clockDigital, .bigDate, .retroLED, .yearProgress: .clockDate
        case .countdown, .anniversary, .starryNight: .special
        }
    }

    /// Marked "New" in the gallery.
    public var isNew: Bool {
        switch self {
        case .sporty, .minimal, .premium, .dashboard, .photo, .clockAnalog, .clockDigital, .countdown, .anniversary, .myCar: false
        default: true
        }
    }

    public var displayName: String {
        switch self {
        case .sporty: "Sporty"
        case .minimal: "Minimal"
        case .premium: "Premium"
        case .dashboard: "Dashboard"
        case .photo: "Photo"
        case .clockAnalog: "Clock (analogue)"
        case .clockDigital: "Clock (digital)"
        case .countdown: "Countdown"
        case .anniversary: "Anniversary"
        case .myCar: "My Car"
        case .boldTile: "Bold Tile"
        case .neonRing: "Neon Ring"
        case .twinGauges: "Twin Gauges"
        case .aurora: "Aurora"
        case .sunsetDrive: "Sunset Drive"
        case .nightDrive: "Night Drive"
        case .showroom: "Showroom"
        case .racingStripes: "Racing Stripes"
        case .starryNight: "Starry Night"
        case .bigDate: "Big Date"
        case .yearProgress: "Year Progress"
        case .retroLED: "Retro LED"
        }
    }

    /// Templates that take a data source (the rest have their own content).
    public var usesDataSource: Bool {
        switch self {
        case .sporty, .minimal, .premium, .dashboard, .photo, .myCar,
             .boldTile, .neonRing, .twinGauges, .aurora, .sunsetDrive, .nightDrive, .showroom, .racingStripes: true
        case .clockAnalog, .clockDigital, .countdown, .anniversary, .starryNight, .bigDate, .yearProgress, .retroLED: false
        }
    }
}

/// Template gallery sections.
public enum TemplateGroup: String, CaseIterable, Sendable, Identifiable {
    case data, car, clockDate, special

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .data: "Data"
        case .car: "Car"
        case .clockDate: "Clock & Date"
        case .special: "Special"
        }
    }

    public var styles: [TemplateStyle] { TemplateStyle.allCases.filter { $0.group == self } }
}

/// The main and second value a data source contributes to a template.
public struct TemplateBinding: Sendable {
    public let primary: DataField
    public let secondary: DataField?
    public let label: String
    public let symbol: String

    public static func of(_ source: DataSource) -> TemplateBinding {
        switch source {
        case .service: TemplateBinding(primary: .kmToService, secondary: .serviceItem, label: "Service", symbol: "wrench.and.screwdriver.fill")
        case .fuel: TemplateBinding(primary: .kmPerLitre, secondary: .fuelSpendMonth, label: "Fuel", symbol: "fuelpump.fill")
        case .renewals: TemplateBinding(primary: .daysToRoadTax, secondary: .nearestRenewal, label: "Road tax", symbol: "calendar.badge.clock")
        case .tng: TemplateBinding(primary: .tngBalance, secondary: nil, label: "Touch 'n Go", symbol: "creditcard.fill")
        case .parking: TemplateBinding(primary: .parkingPlace, secondary: .parkingTime, label: "Parking", symbol: "parkingsign.circle.fill")
        case .prayer: TemplateBinding(primary: .prayerCountdown, secondary: .nextPrayerName, label: "Prayer", symbol: "moon.stars.fill")
        case .commute: TemplateBinding(primary: .commuteTime, secondary: .nextEvent, label: "Commute", symbol: "car.rear.road.lane")
        case .weather: TemplateBinding(primary: .temperature, secondary: .airQuality, label: "Weather", symbol: "cloud.sun.fill")
        case .map: TemplateBinding(primary: .parkingPlace, secondary: .parkingTime, label: "Parking", symbol: "map.fill")
        case .photos: TemplateBinding(primary: .date, secondary: .clock, label: "Today", symbol: "photo")
        case .music: TemplateBinding(primary: .musicTitle, secondary: nil, label: "Music", symbol: "music.note")
        case .obd: TemplateBinding(primary: .boost, secondary: .coolantTemp, label: "Boost", symbol: "gauge.with.dots.needle.67percent")
        case .lyrics: TemplateBinding(primary: .musicTitle, secondary: nil, label: "Now playing", symbol: "quote.bubble.fill")
        }
    }
}

public enum Templates {
    /// A new design from a template. `photoFile` is used by the Photo template (a Photo Frame file).
    public static func make(_ style: TemplateStyle, source: DataSource = .service, canvas: DesignCanvas = .small, photoFile: String? = nil, eventDate: Date? = nil, eventName: String = "Married") -> CardDesign {
        let bind = TemplateBinding.of(source)
        let wide = canvas == .medium
        let accent = Theme.Hex.accent
        let white: UInt32 = 0xFFFFFF
        let grey = Theme.Hex.secondaryText
        var layers: [DesignLayer] = []
        let background: DesignBackground

        switch style {
        case .sporty:
            background = .texture(.carbon, 0x111318)
            layers = [
                DesignLayer(content: .gauge(bind.primary), x: wide ? 0.2 : 0.5, y: 0.52, width: wide ? 0.36 : 0.9, height: 0.86, colorHex: 0xE5484D),
                DesignLayer(content: .symbol(bind.symbol), x: wide ? 0.2 : 0.5, y: 0.33, width: 0.14, height: 0.16, colorHex: accent),
                DesignLayer(content: .data(bind.primary), x: wide ? 0.66 : 0.5, y: wide ? 0.42 : 0.6, width: wide ? 0.6 : 0.7, height: 0.26, font: .orbitron, weight: .bold, fontSize: wide ? 30 : 22, colorHex: white, alignment: wide ? .leading : .center),
                DesignLayer(content: .text(bind.label.uppercased()), x: wide ? 0.66 : 0.5, y: wide ? 0.66 : 0.82, width: wide ? 0.6 : 0.7, height: 0.12, font: .orbitron, weight: .semibold, fontSize: 14, colorHex: accent, alignment: wide ? .leading : .center),
                DesignLayer(content: .sticker(.speedLines), x: wide ? 0.8 : 0.5, y: 0.12, width: wide ? 0.35 : 0.6, height: 0.14, opacity: 0.8, colorHex: 0xE5484D),
            ]

        case .minimal:
            background = .solid(0x0A0B0F)
            layers = [
                DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.48, width: 0.88, height: 0.42, font: .system, weight: .semibold, fontSize: wide ? 46 : 36, colorHex: white, alignment: .leading),
                DesignLayer(content: .text(bind.label.lowercased()), x: 0.5, y: 0.78, width: 0.88, height: 0.14, font: .system, weight: .regular, fontSize: 15, colorHex: grey, alignment: .leading),
            ]

        case .premium:
            background = .gradient(0x1C1F2A, 0x050608)
            layers = [
                DesignLayer(content: .text(bind.label), x: 0.5, y: 0.2, width: 0.86, height: 0.16, font: .playfair, weight: .regular, fontSize: 18, colorHex: 0xD9C08C, alignment: .leading),
                DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.52, width: 0.86, height: 0.34, font: .playfair, weight: .bold, fontSize: wide ? 38 : 30, colorHex: white, alignment: .leading, shadow: true),
            ]
            if let secondary = bind.secondary {
                layers.append(DesignLayer(content: .data(secondary), x: 0.5, y: 0.8, width: 0.86, height: 0.14, font: .serif, weight: .regular, fontSize: 14, colorHex: grey, alignment: .leading))
            }

        case .dashboard:
            background = .texture(.brushed, 0x14161C)
            let fields: [DataField] = [bind.primary, bind.secondary ?? .clock, .temperature, .tngBalance]
            let count = wide ? 4 : 2
            layers = fields.prefix(count).enumerated().map { index, field in
                DesignLayer(
                    content: .data(field),
                    x: wide ? 0.13 + Double(index) * 0.245 : 0.5,
                    y: wide ? 0.55 : 0.3 + Double(index) * 0.42,
                    width: wide ? 0.23 : 0.86,
                    height: wide ? 0.6 : 0.38,
                    font: .rajdhani, weight: .bold, fontSize: 22, colorHex: white, alignment: .leading,
                    caption: field.displayName
                )
            }

        case .photo:
            background = photoFile.map { .photo($0) } ?? .gradient(accent, 0x0A0B0F)
            layers = [
                DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.8, width: 0.88, height: 0.22, font: .rounded, weight: .bold, fontSize: 22, colorHex: white, alignment: .leading, shadow: true),
            ]

        case .clockAnalog:
            background = .gradient(Theme.Hex.surface, 0x050608)
            layers = [DesignLayer(content: .analogClock, x: wide ? 0.25 : 0.5, y: 0.5, width: wide ? 0.42 : 0.86, height: 0.86, colorHex: white)]
            if wide {
                layers.append(DesignLayer(content: .data(.date), x: 0.7, y: 0.5, width: 0.5, height: 0.3, font: .rounded, weight: .bold, fontSize: 24, colorHex: white, alignment: .leading))
            }

        case .clockDigital:
            background = .gradient(0x101828, 0x050608)
            layers = [
                DesignLayer(content: .data(.clock), x: 0.5, y: 0.45, width: 0.9, height: 0.36, font: .orbitron, weight: .bold, fontSize: wide ? 40 : 26, colorHex: white, alignment: .center),
                DesignLayer(content: .data(.date), x: 0.5, y: 0.76, width: 0.9, height: 0.16, font: .rounded, weight: .semibold, fontSize: 15, colorHex: grey, alignment: .center),
            ]

        case .countdown:
            background = .gradient(accent, 0x0A0B0F)
            layers = [
                DesignLayer(content: .text(eventName), x: 0.5, y: 0.22, width: 0.86, height: 0.18, font: .rounded, weight: .semibold, fontSize: 17, colorHex: white, alignment: .leading),
                DesignLayer(content: .data(.countdownDays), x: 0.5, y: 0.58, width: 0.86, height: 0.36, font: .rounded, weight: .heavy, fontSize: wide ? 44 : 32, colorHex: white, alignment: .leading),
            ]

        case .anniversary:
            background = .gradient(0x3A1C4A, 0x0A0B0F)
            layers = [
                DesignLayer(content: .sticker(.heart), x: 0.82, y: 0.2, width: 0.2, height: 0.2, colorHex: 0xE5484D),
                DesignLayer(content: .text(eventName), x: 0.5, y: 0.24, width: 0.86, height: 0.18, font: .playfair, weight: .semibold, fontSize: 18, colorHex: 0xF3D9E8, alignment: .leading),
                DesignLayer(content: .data(.dayCounter), x: 0.5, y: 0.62, width: 0.86, height: 0.4, font: .playfair, weight: .bold, fontSize: wide ? 30 : 22, colorHex: white, alignment: .leading),
            ]

        case .myCar:
            background = .gradient(accent, 0x0A1A4A)
            layers = [
                DesignLayer(content: .carPhoto, x: wide ? 0.3 : 0.5, y: wide ? 0.5 : 0.4, width: wide ? 0.55 : 0.95, height: wide ? 0.9 : 0.6, colorHex: white),
                DesignLayer(content: .data(bind.primary), x: wide ? 0.76 : 0.5, y: wide ? 0.4 : 0.8, width: wide ? 0.44 : 0.9, height: 0.18, font: .rounded, weight: .bold, fontSize: wide ? 22 : 17, colorHex: white, alignment: wide ? .leading : .center, shadow: true, caption: wide ? bind.label : nil),
            ]
            if wide {
                layers.append(DesignLayer(content: .plate(""), x: 0.76, y: 0.74, width: 0.36, height: 0.17, fontSize: 16))
            }

        case .boldTile:
            background = .stateColor(boldHex(for: source))
            layers = [
                DesignLayer(content: .symbol(bind.symbol), x: wide ? 0.07 : 0.15, y: 0.17, width: wide ? 0.07 : 0.15, height: 0.15, opacity: 0.9, colorHex: white),
                DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.52, width: 0.9, height: 0.42, font: .rounded, weight: .heavy, fontSize: wide ? 54 : 42, colorHex: white, alignment: .center, shadow: true),
                DesignLayer(content: .text(bind.label.uppercased()), x: 0.5, y: 0.82, width: 0.9, height: 0.13, opacity: 0.85, font: .rounded, weight: .bold, fontSize: 14, colorHex: white, alignment: .center),
            ]

        case .neonRing:
            let neon: UInt32 = 0x22D3EE
            background = .solid(0x05060A)
            if wide {
                layers = [
                    DesignLayer(content: .ring(bind.primary), x: 0.2, y: 0.5, width: 0.36, height: 0.82, colorHex: neon, glow: true),
                    DesignLayer(content: .symbol(bind.symbol), x: 0.2, y: 0.5, width: 0.09, height: 0.22, colorHex: neon, glow: true),
                    DesignLayer(content: .data(bind.primary), x: 0.67, y: 0.44, width: 0.6, height: 0.36, font: .rounded, weight: .heavy, fontSize: 38, colorHex: white, alignment: .leading, glow: true),
                    DesignLayer(content: .text(bind.label.uppercased()), x: 0.67, y: 0.72, width: 0.6, height: 0.14, font: .rounded, weight: .bold, fontSize: 14, colorHex: neon, alignment: .leading),
                ]
            } else {
                layers = [
                    DesignLayer(content: .ring(bind.primary), x: 0.5, y: 0.5, width: 0.88, height: 0.88, colorHex: neon, glow: true),
                    DesignLayer(content: .symbol(bind.symbol), x: 0.5, y: 0.3, width: 0.14, height: 0.12, colorHex: neon),
                    DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.52, width: 0.6, height: 0.24, font: .rounded, weight: .heavy, fontSize: 26, colorHex: white, alignment: .center, glow: true),
                    DesignLayer(content: .text(bind.label.uppercased()), x: 0.5, y: 0.7, width: 0.56, height: 0.1, font: .rounded, weight: .bold, fontSize: 14, colorHex: neon, alignment: .center),
                ]
            }

        case .twinGauges:
            background = .texture(.carbon, 0x0B0D12)
            let second = bind.secondary ?? .yearProgress
            let orange: UInt32 = 0xFB923C, cyan: UInt32 = 0x22D3EE
            let gw = wide ? 0.3 : 0.48
            layers = [
                DesignLayer(content: .gauge(bind.primary), x: wide ? 0.27 : 0.26, y: 0.42, width: gw, height: wide ? 0.78 : 0.5, colorHex: orange, glow: true),
                DesignLayer(content: .gauge(second), x: wide ? 0.73 : 0.74, y: 0.42, width: gw, height: wide ? 0.78 : 0.5, colorHex: cyan, glow: true),
                DesignLayer(content: .data(bind.primary), x: wide ? 0.27 : 0.26, y: wide ? 0.5 : 0.46, width: wide ? 0.24 : 0.36, height: 0.2, font: .rajdhani, weight: .bold, fontSize: wide ? 26 : 18, colorHex: white, alignment: .center),
                DesignLayer(content: .data(second), x: wide ? 0.73 : 0.74, y: wide ? 0.5 : 0.46, width: wide ? 0.24 : 0.36, height: 0.2, font: .rajdhani, weight: .bold, fontSize: wide ? 26 : 18, colorHex: white, alignment: .center),
                DesignLayer(content: .text(bind.label.uppercased()), x: 0.5, y: wide ? 0.9 : 0.82, width: 0.9, height: 0.12, font: .rajdhani, weight: .bold, fontSize: 14, colorHex: orange, alignment: .center),
            ]

        case .aurora:
            background = .aurora(0x7C3AED, 0x06B6D4, 0xF43F5E)
            layers = [
                DesignLayer(content: .symbol(bind.symbol), x: wide ? 0.07 : 0.15, y: 0.17, width: wide ? 0.07 : 0.15, height: 0.15, colorHex: white),
                DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.53, width: 0.9, height: 0.4, font: .rounded, weight: .heavy, fontSize: wide ? 50 : 38, colorHex: white, alignment: wide ? .leading : .center, shadow: true),
                DesignLayer(content: .text(bind.label), x: 0.5, y: 0.82, width: 0.9, height: 0.13, font: .rounded, weight: .semibold, fontSize: 15, colorHex: white, alignment: wide ? .leading : .center),
            ]

        case .sunsetDrive:
            background = .gradient(0xFF8A3D, 0x3B1C6E)
            if wide {
                layers = [
                    DesignLayer(content: .sticker(.sun), x: 0.27, y: 0.42, width: 0.3, height: 0.62, colorHex: 0xFF4D6D),
                    DesignLayer(content: .sticker(.road), x: 0.27, y: 0.86, width: 0.54, height: 0.3, colorHex: 0xFFD166),
                    DesignLayer(content: .data(bind.primary), x: 0.74, y: 0.44, width: 0.48, height: 0.34, font: .rounded, weight: .heavy, fontSize: 34, colorHex: white, alignment: .leading, shadow: true),
                    DesignLayer(content: .text(bind.label.uppercased()), x: 0.74, y: 0.7, width: 0.48, height: 0.14, font: .rounded, weight: .bold, fontSize: 14, colorHex: 0xFFE4C4, alignment: .leading),
                ]
            } else {
                layers = [
                    DesignLayer(content: .sticker(.sun), x: 0.5, y: 0.5, width: 0.56, height: 0.56, colorHex: 0xFF4D6D),
                    DesignLayer(content: .sticker(.road), x: 0.5, y: 0.87, width: 1.0, height: 0.28, colorHex: 0xFFD166),
                    DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.17, width: 0.9, height: 0.22, font: .rounded, weight: .heavy, fontSize: 26, colorHex: white, alignment: .center, shadow: true),
                ]
            }

        case .nightDrive:
            let ice: UInt32 = 0x7DD3FC
            background = .spotlight(0x1E3A8A, 0x020617)
            if wide {
                layers = [
                    DesignLayer(content: .carPhoto, x: 0.32, y: 0.52, width: 0.6, height: 0.86, colorHex: white),
                    DesignLayer(content: .data(bind.primary), x: 0.78, y: 0.44, width: 0.42, height: 0.32, font: .rounded, weight: .heavy, fontSize: 30, colorHex: ice, alignment: .leading, glow: true),
                    DesignLayer(content: .text(bind.label.uppercased()), x: 0.78, y: 0.68, width: 0.42, height: 0.14, font: .rounded, weight: .bold, fontSize: 14, colorHex: 0xBFDBFE, alignment: .leading),
                ]
            } else {
                layers = [
                    DesignLayer(content: .carPhoto, x: 0.5, y: 0.44, width: 0.98, height: 0.6, colorHex: white),
                    DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.84, width: 0.9, height: 0.2, font: .rounded, weight: .heavy, fontSize: 22, colorHex: ice, alignment: .center, glow: true),
                ]
            }

        case .showroom:
            background = .spotlight(0x6B7A99, 0x07080C)
            if wide {
                layers = [
                    DesignLayer(content: .carPhoto, x: 0.34, y: 0.52, width: 0.64, height: 0.88, colorHex: white),
                    DesignLayer(content: .data(bind.primary), x: 0.8, y: 0.36, width: 0.38, height: 0.26, font: .rounded, weight: .bold, fontSize: 24, colorHex: white, alignment: .center, shadow: true, caption: bind.label),
                    DesignLayer(content: .plate(""), x: 0.8, y: 0.72, width: 0.34, height: 0.17, fontSize: 16),
                ]
            } else {
                layers = [
                    DesignLayer(content: .data(bind.primary), x: 0.5, y: 0.13, width: 0.9, height: 0.16, font: .rounded, weight: .bold, fontSize: 18, colorHex: white, alignment: .center, shadow: true),
                    DesignLayer(content: .carPhoto, x: 0.5, y: 0.5, width: 0.98, height: 0.58, colorHex: white),
                    DesignLayer(content: .plate(""), x: 0.5, y: 0.87, width: 0.52, height: 0.14, fontSize: 14),
                ]
            }

        case .racingStripes:
            background = .solid(0xD7263D)
            layers = [
                DesignLayer(content: .progressBar(nil), x: wide ? 0.84 : 0.8, y: 0.5, width: 1.6, height: wide ? 0.13 : 0.11, rotation: -62, opacity: 0.95, colorHex: white),
                DesignLayer(content: .progressBar(nil), x: wide ? 0.93 : 0.95, y: 0.5, width: 1.6, height: wide ? 0.13 : 0.11, rotation: -62, opacity: 0.95, colorHex: white),
                DesignLayer(content: .sticker(.flag), x: wide ? 0.06 : 0.13, y: 0.17, width: wide ? 0.07 : 0.14, height: 0.14, colorHex: white),
                DesignLayer(content: .data(bind.primary), x: wide ? 0.4 : 0.42, y: 0.54, width: wide ? 0.72 : 0.76, height: 0.34, font: .orbitron, weight: .heavy, fontSize: wide ? 34 : 24, colorHex: white, alignment: .leading, shadow: true),
                DesignLayer(content: .text(bind.label.uppercased()), x: wide ? 0.4 : 0.42, y: 0.8, width: wide ? 0.72 : 0.76, height: 0.13, font: .orbitron, weight: .bold, fontSize: 14, colorHex: 0xFFE4E6, alignment: .leading),
            ]

        case .starryNight:
            background = .gradient(0x1E1B4B, 0x020617)
            layers = [
                DesignLayer(content: .sticker(.starfield), x: 0.5, y: 0.5, width: 1, height: 1, colorHex: white),
                DesignLayer(content: .sticker(.crescent), x: wide ? 0.88 : 0.78, y: 0.24, width: wide ? 0.16 : 0.3, height: 0.32, colorHex: 0xFDE68A, glow: true),
                DesignLayer(content: .data(.nextPrayerName), x: wide ? 0.36 : 0.45, y: 0.5, width: wide ? 0.64 : 0.82, height: 0.18, font: .rounded, weight: .semibold, fontSize: 18, colorHex: 0xC7D2FE, alignment: .leading),
                DesignLayer(content: .data(.prayerCountdown), x: wide ? 0.36 : 0.45, y: 0.74, width: wide ? 0.64 : 0.82, height: 0.28, font: .rounded, weight: .heavy, fontSize: wide ? 40 : 30, colorHex: white, alignment: .leading, glow: true),
            ]

        case .bigDate:
            background = .gradient(0xFFFFFF, 0xE2E8F0)
            let red: UInt32 = 0xE11D48, ink: UInt32 = 0x0F172A
            if wide {
                layers = [
                    DesignLayer(content: .data(.dayOfMonth), x: 0.24, y: 0.52, width: 0.4, height: 0.8, font: .rounded, weight: .heavy, fontSize: 92, colorHex: ink, alignment: .center),
                    DesignLayer(content: .data(.weekday), x: 0.7, y: 0.4, width: 0.52, height: 0.2, font: .rounded, weight: .heavy, fontSize: 24, colorHex: red, alignment: .leading),
                    DesignLayer(content: .data(.monthName), x: 0.7, y: 0.62, width: 0.52, height: 0.16, font: .rounded, weight: .bold, fontSize: 16, colorHex: 0x475569, alignment: .leading),
                ]
            } else {
                layers = [
                    DesignLayer(content: .data(.weekday), x: 0.5, y: 0.17, width: 0.9, height: 0.16, font: .rounded, weight: .heavy, fontSize: 17, colorHex: red, alignment: .center),
                    DesignLayer(content: .data(.dayOfMonth), x: 0.5, y: 0.6, width: 0.9, height: 0.66, font: .rounded, weight: .heavy, fontSize: 86, colorHex: ink, alignment: .center),
                ]
            }

        case .yearProgress:
            let mint: UInt32 = 0x34D399
            background = .gradient(0x0F172A, 0x020617)
            layers = [
                DesignLayer(content: .text("THIS YEAR"), x: 0.5, y: 0.2, width: 0.84, height: 0.13, font: .rounded, weight: .bold, fontSize: 14, colorHex: 0x94A3B8, alignment: .leading),
                DesignLayer(content: .data(.yearProgress), x: 0.5, y: 0.48, width: 0.84, height: 0.38, font: .rounded, weight: .heavy, fontSize: wide ? 56 : 46, colorHex: white, alignment: .leading),
                DesignLayer(content: .progressBar(.yearProgress), x: 0.5, y: 0.8, width: 0.84, height: 0.09, colorHex: mint, glow: true),
            ]

        case .retroLED:
            let amber: UInt32 = 0xFFB020
            background = .solid(0x050505)
            layers = [
                DesignLayer(content: .data(.clock), x: 0.5, y: 0.45, width: 0.92, height: 0.4, font: .mono, weight: .heavy, fontSize: wide ? 48 : 30, colorHex: amber, alignment: .center, glow: true),
                DesignLayer(content: .data(.date), x: 0.5, y: 0.76, width: 0.9, height: 0.15, opacity: 0.75, font: .mono, weight: .bold, fontSize: 15, colorHex: amber, alignment: .center),
            ]
        }

        let name = style.usesDataSource ? "\(style.displayName) · \(bind.label)" : style.displayName
        return CardDesign(name: name, canvas: canvas, background: background, layers: layers, template: style.rawValue, eventDate: eventDate)
    }

    /// Each source's own colour for Bold Tile (it turns amber or red when the value needs attention).
    public static func boldHex(for source: DataSource) -> UInt32 {
        CardPaint(source: source).hex(.bold)
    }

    /// The design a seasonal pack shows (iftar countdown in Ramadan, greetings otherwise).
    public static func seasonal(_ occasion: SeasonalOccasion, canvas: DesignCanvas = .small) -> CardDesign {
        let wide = canvas == .medium
        let gold: UInt32 = 0xF5C542
        let white: UInt32 = 0xFFFFFF
        func design(_ background: DesignBackground, art: ArtworkKind, artColor: UInt32, title: String, subtitle: DataField? = nil, subtitleText: String? = nil) -> CardDesign {
            var layers = [
                // Rendered artwork from /remotion; `art` is drawn instead if the PNG is missing.
                DesignLayer(content: .seasonalArt(occasion), x: wide ? 0.82 : 0.72, y: wide ? 0.5 : 0.3, width: wide ? 0.3 : 0.48, height: wide ? 0.8 : 0.46, colorHex: artColor),
                DesignLayer(content: .text(title), x: wide ? 0.36 : 0.5, y: wide ? 0.38 : 0.66, width: wide ? 0.64 : 0.9, height: 0.28, font: .playfair, weight: .bold, fontSize: wide ? 24 : 19, colorHex: white, alignment: .leading, shadow: true),
            ]
            if let subtitle {
                layers.append(DesignLayer(content: .data(subtitle), x: wide ? 0.36 : 0.5, y: wide ? 0.72 : 0.88, width: wide ? 0.64 : 0.9, height: 0.16, font: .rounded, weight: .semibold, fontSize: 16, colorHex: gold, alignment: .leading))
            } else if let subtitleText {
                layers.append(DesignLayer(content: .text(subtitleText), x: wide ? 0.36 : 0.5, y: wide ? 0.72 : 0.88, width: wide ? 0.64 : 0.9, height: 0.16, font: .rounded, weight: .semibold, fontSize: 15, colorHex: gold, alignment: .leading))
            }
            return CardDesign(name: occasion.displayName, canvas: canvas, background: background, layers: layers, template: "seasonal.\(occasion.rawValue)")
        }

        switch occasion {
        case .ramadan:
            return design(.gradient(0x0B3D2E, 0x04140F), art: .crescent, artColor: gold, title: "Iftar in", subtitle: .iftarCountdown)
        case .hariRaya:
            return design(.gradient(0x0E6B3A, 0x053019), art: .ketupat, artColor: 0x7BC67E, title: "Selamat Hari Raya", subtitleText: "Maaf zahir & batin")
        case .aidiladha:
            return design(.gradient(0x14532D, 0x052E16), art: .crescent, artColor: gold, title: "Salam Aidiladha", subtitle: .nextPrayerName)
        case .merdeka:
            return design(.solid(0x010066), art: .stripes, artColor: white, title: "Selamat Hari Merdeka", subtitleText: "31 Ogos · 16 September")
        case .chineseNewYear:
            return design(.gradient(0xB91C1C, 0x450A0A), art: .lantern, artColor: 0xE5484D, title: "Gong Xi Fa Cai", subtitleText: "Happy Chinese New Year")
        case .deepavali:
            return design(.gradient(0x6B21A8, 0x1E0B36), art: .diya, artColor: 0xF59E0B, title: "Happy Deepavali", subtitleText: "Festival of Lights")
        case .christmas:
            return design(.gradient(0x14532D, 0x0A0B0F), art: .tree, artColor: 0x22C55E, title: "Merry Christmas", subtitle: .date)
        case .newYear:
            return design(.gradient(0x111827, 0x000000), art: .fireworks, artColor: 0x60A5FA, title: "Happy New Year", subtitle: .clock)
        }
    }
}
