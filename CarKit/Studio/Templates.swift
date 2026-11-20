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

    public var id: String { rawValue }

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
        }
    }

    /// Templates that take a data source (the rest have their own content).
    public var usesDataSource: Bool {
        switch self {
        case .sporty, .minimal, .premium, .dashboard, .photo, .myCar: true
        case .clockAnalog, .clockDigital, .countdown, .anniversary: false
        }
    }
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
        }

        let name = style.usesDataSource ? "\(style.displayName) · \(bind.label)" : style.displayName
        return CardDesign(name: name, canvas: canvas, background: background, layers: layers, template: style.rawValue, eventDate: eventDate)
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
