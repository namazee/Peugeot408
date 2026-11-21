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
    /// Panorama hero across Slots 1–3 (always the panorama canvas).
    case hero
    // Realistic templates (Phase 16): each has its own Small and Medium layout.
    case chromeDial
    case fuelGauge
    case odometer
    case highwaySign
    case leatherStitch
    case digitalCockpit
    case headUpDisplay
    case frostedGlass
    case liveSky
    case boardingPass
    // Phase 17: more realistic templates (Small and Medium) and Hero templates (panorama).
    case splitFlap
    case neonSign
    case woodTrim
    case carStereo
    case navigation
    case rainyWindow
    case parkingTicket
    case numberPlate
    case heroSunsetRoad
    case heroNightCity
    case heroCockpit
    case heroLiveSky
    case heroNeonGrid
    case heroGlassInfo
    // Phase 18: another round of realistic, other and Hero templates.
    case shiftLight
    case polaroid
    case stickyNote
    case dotMatrix
    case chalkboard
    case thermometer
    case battery
    case speedSign
    case vinyl
    case comicPop
    case flipClock
    case wordClock
    case hijriDate
    case moonPhase
    case heroGarage
    case heroCoastal
    case heroRainCity
    case heroStartingGrid
    case heroMountainPass
    case heroDepartureBoard

    public var id: String { rawValue }

    /// Gallery section.
    public var group: TemplateGroup {
        switch self {
        case .sporty, .minimal, .premium, .dashboard, .boldTile, .neonRing, .twinGauges, .aurora, .racingStripes: .data
        case .myCar, .photo, .nightDrive, .showroom, .sunsetDrive: .car
        case .heroGarage, .heroCoastal, .heroRainCity, .heroStartingGrid, .heroMountainPass, .heroDepartureBoard: .hero
        case .vinyl, .comicPop: .data
        case .flipClock, .wordClock, .hijriDate: .clockDate
        case .moonPhase: .special
        case .hero, .heroSunsetRoad, .heroNightCity, .heroCockpit, .heroLiveSky, .heroNeonGrid, .heroGlassInfo: .hero
        case .clockAnalog, .clockDigital, .bigDate, .retroLED, .yearProgress: .clockDate
        case .countdown, .anniversary, .starryNight: .special
        case .chromeDial, .fuelGauge, .odometer, .highwaySign, .leatherStitch, .digitalCockpit,
             .headUpDisplay, .frostedGlass, .liveSky, .boardingPass,
             .splitFlap, .neonSign, .woodTrim, .carStereo, .navigation, .rainyWindow, .parkingTicket, .numberPlate,
             .shiftLight, .polaroid, .stickyNote, .dotMatrix, .chalkboard, .thermometer, .battery, .speedSign: .realistic
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
        case .hero: "Hero (Panorama)"
        case .chromeDial: "Chrome Dial"
        case .fuelGauge: "Fuel Gauge"
        case .odometer: "Odometer"
        case .highwaySign: "Highway Sign"
        case .leatherStitch: "Leather Stitch"
        case .digitalCockpit: "Digital Cockpit"
        case .headUpDisplay: "Head-Up Display"
        case .frostedGlass: "Frosted Glass"
        case .liveSky: "Live Sky"
        case .boardingPass: "Boarding Pass"
        case .splitFlap: "Split-Flap"
        case .neonSign: "Neon Sign"
        case .woodTrim: "Wood Trim"
        case .carStereo: "Car Stereo"
        case .navigation: "Navigation"
        case .rainyWindow: "Rainy Window"
        case .parkingTicket: "Parking Ticket"
        case .numberPlate: "Number Plate"
        case .heroSunsetRoad: "Sunset Road"
        case .heroNightCity: "Night City"
        case .heroCockpit: "Cockpit"
        case .heroLiveSky: "Live Sky"
        case .heroNeonGrid: "Neon Grid"
        case .heroGlassInfo: "Glass Info"
        case .shiftLight: "Shift Lights"
        case .polaroid: "Polaroid"
        case .stickyNote: "Sticky Note"
        case .dotMatrix: "Dot Matrix"
        case .chalkboard: "Chalkboard"
        case .thermometer: "Thermometer"
        case .battery: "Battery"
        case .speedSign: "Speed Sign"
        case .vinyl: "Vinyl"
        case .comicPop: "Comic Pop"
        case .flipClock: "Flip Clock"
        case .wordClock: "Word Clock"
        case .hijriDate: "Hijri Date"
        case .moonPhase: "Moon Phase"
        case .heroGarage: "Garage"
        case .heroCoastal: "Coastal Drive"
        case .heroRainCity: "Rain City"
        case .heroStartingGrid: "Starting Grid"
        case .heroMountainPass: "Mountain Pass"
        case .heroDepartureBoard: "Departure Board"
        }
    }

    /// Templates that take a data source (the rest have their own content).
    public var usesDataSource: Bool {
        switch self {
        case .sporty, .minimal, .premium, .dashboard, .photo, .myCar,
             .boldTile, .neonRing, .twinGauges, .aurora, .sunsetDrive, .nightDrive, .showroom, .racingStripes,
             .chromeDial, .fuelGauge, .odometer, .highwaySign, .leatherStitch, .digitalCockpit,
             .headUpDisplay, .frostedGlass, .liveSky, .boardingPass,
             .splitFlap, .neonSign, .woodTrim, .carStereo, .navigation, .rainyWindow, .parkingTicket, .numberPlate,
             .shiftLight, .polaroid, .stickyNote, .dotMatrix, .chalkboard, .thermometer, .battery, .speedSign, .vinyl, .comicPop: true
        case .clockAnalog, .clockDigital, .countdown, .anniversary, .starryNight, .bigDate, .yearProgress, .retroLED, .hero,
             .heroSunsetRoad, .heroNightCity, .heroCockpit, .heroLiveSky, .heroNeonGrid, .heroGlassInfo,
             .flipClock, .wordClock, .hijriDate, .moonPhase, .heroGarage, .heroCoastal, .heroRainCity, .heroStartingGrid, .heroMountainPass, .heroDepartureBoard: false
        }
    }
}

/// Template gallery sections.
public enum TemplateGroup: String, CaseIterable, Sendable, Identifiable {
    /// Shown first (Phase 16).
    case realistic
    /// Panorama designs across Slots 1–3 (Phase 17); always previewed at the panorama shape.
    case hero
    case data, car, clockDate, special

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .realistic: "Realistic"
        case .hero: "Hero"
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
        let surface = style.group == .hero ? DesignCanvas.panorama : canvas
        let wide = surface != .small
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

        case .hero:
            // One picture across Slots 1–3: greeting and clock on top, big lettering behind the
            // car in the middle, the weather along the bottom. No brand logos.
            background = .spotlight(0x2A5BD7, 0x04060C)
            layers = [
                DesignLayer(content: .text(eventName == "Married" ? "MY CAR" : eventName), x: 0.5, y: 0.4, width: 0.98, height: 0.52, opacity: 0.2, font: .orbitron, weight: .heavy, fontSize: 118, colorHex: white, alignment: .center),
                DesignLayer(content: .carPhoto, x: 0.5, y: 0.6, width: 0.6, height: 0.7, colorHex: white),
                DesignLayer(content: .data(.greeting), x: 0.155, y: 0.11, width: 0.27, height: 0.12, font: .rounded, weight: .bold, fontSize: 17, colorHex: white, alignment: .leading, shadow: true),
                DesignLayer(content: .data(.clock), x: 0.84, y: 0.11, width: 0.28, height: 0.12, font: .rounded, weight: .bold, fontSize: 20, colorHex: white, alignment: .trailing, shadow: true),
                DesignLayer(content: .data(.temperature), x: 0.12, y: 0.82, width: 0.2, height: 0.14, font: .rounded, weight: .heavy, fontSize: 28, colorHex: white, alignment: .leading, shadow: true),
                DesignLayer(content: .data(.weatherPlace), x: 0.17, y: 0.92, width: 0.3, height: 0.08, font: .rounded, weight: .semibold, fontSize: 14, colorHex: 0xBFD3FF, alignment: .leading),
                DesignLayer(content: .plate(""), x: 0.86, y: 0.88, width: 0.17, height: 0.11, fontSize: 15),
            ]

        case .retroLED:
            let amber: UInt32 = 0xFFB020
            background = .solid(0x050505)
            layers = [
                DesignLayer(content: .data(.clock), x: 0.5, y: 0.45, width: 0.92, height: 0.4, font: .mono, weight: .heavy, fontSize: wide ? 48 : 30, colorHex: amber, alignment: .center, glow: true),
                DesignLayer(content: .data(.date), x: 0.5, y: 0.76, width: 0.9, height: 0.15, opacity: 0.75, font: .mono, weight: .bold, fontSize: 15, colorHex: amber, alignment: .center),
            ]

        case .chromeDial, .fuelGauge, .odometer, .highwaySign, .leatherStitch, .digitalCockpit,
             .headUpDisplay, .frostedGlass, .liveSky, .boardingPass,
             .splitFlap, .neonSign, .woodTrim, .carStereo, .navigation, .rainyWindow, .parkingTicket, .numberPlate,
             .shiftLight, .polaroid, .stickyNote, .dotMatrix, .chalkboard, .thermometer, .battery, .speedSign, .vinyl, .comicPop, .flipClock, .wordClock, .hijriDate, .moonPhase:
            let made = realistic(style, bind: bind, wide: wide)
            background = made.0
            layers = made.1

        case .heroSunsetRoad, .heroNightCity, .heroCockpit, .heroLiveSky, .heroNeonGrid, .heroGlassInfo,
             .heroGarage, .heroCoastal, .heroRainCity, .heroStartingGrid, .heroMountainPass, .heroDepartureBoard:
            let made = hero(style)
            background = made.0
            layers = made.1
        }

        let name = style.usesDataSource ? "\(style.displayName) · \(bind.label)" : style.displayName
        return CardDesign(name: name, canvas: surface, background: background, layers: layers, template: style.rawValue, eventDate: eventDate)
    }

    /// The realistic templates (spec §4b, Phase 16). Small and Medium each get their own layout.
    static func realistic(_ style: TemplateStyle, bind: TemplateBinding, wide: Bool) -> (DesignBackground, [DesignLayer]) {
        let white: UInt32 = 0xFFFFFF
        let second = bind.secondary ?? .yearProgress
        let label = bind.label.uppercased()
        func data(_ field: DataField, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ font: DesignFont, _ weight: DesignWeight, _ size: Double,
                  _ color: UInt32, _ align: DesignAlignment, shadow: Bool = false, glow: Bool? = nil, rotation: Double = 0) -> DesignLayer {
            DesignLayer(content: .data(field), x: x, y: y, width: w, height: h, rotation: rotation, font: font, weight: weight, fontSize: size,
                        colorHex: color, alignment: align, shadow: shadow, glow: glow)
        }
        func text(_ string: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ font: DesignFont, _ weight: DesignWeight, _ size: Double,
                  _ color: UInt32, _ align: DesignAlignment, opacity: Double = 1, shadow: Bool = false, glow: Bool? = nil, rotation: Double = 0) -> DesignLayer {
            DesignLayer(content: .text(string), x: x, y: y, width: w, height: h, rotation: rotation, opacity: opacity, font: font, weight: weight, fontSize: size,
                        colorHex: color, alignment: align, shadow: shadow, glow: glow)
        }
        func art(_ content: LayerContent, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32,
                 opacity: Double = 1, glow: Bool? = nil, segments: Int? = nil, rotation: Double = 0) -> DesignLayer {
            DesignLayer(content: content, x: x, y: y, width: w, height: h, rotation: rotation, opacity: opacity, colorHex: color, glow: glow, segments: segments)
        }

        switch style {
        case .chromeDial:
            let needle: UInt32 = 0xFF3B30, ice: UInt32 = 0x7FD4FF, grey: UInt32 = 0xB7BDC7
            if wide {
                return (.texture(.brushed, 0x14161B), [
                    art(.dial(bind.primary, .instrument), 0.19, 0.5, 0.37, 0.94, needle),
                    art(.dial(second, .instrument), 0.81, 0.5, 0.37, 0.94, needle),
                    art(.sticker(.glassPanel), 0.5, 0.5, 0.27, 0.66, white),
                    text(label, 0.5, 0.29, 0.24, 0.12, .rajdhani, .bold, 14, grey, .center),
                    data(bind.primary, 0.5, 0.5, 0.25, 0.26, .rajdhani, .bold, 26, white, .center),
                    data(second, 0.5, 0.71, 0.25, 0.14, .rajdhani, .semibold, 14, ice, .center),
                ])
            }
            return (.texture(.brushed, 0x14161B), [
                art(.dial(bind.primary, .instrument), 0.5, 0.5, 0.96, 0.96, needle),
                text(label, 0.5, 0.64, 0.3, 0.09, .rajdhani, .bold, 14, grey, .center),
                data(bind.primary, 0.5, 0.82, 0.34, 0.13, .rajdhani, .bold, 16, white, .center),
            ])

        case .fuelGauge:
            let needle: UInt32 = 0xFF7A1A, warm: UInt32 = 0xFFB37A, grey: UInt32 = 0xA9B1BE
            if wide {
                return (.spotlight(0x1C2230, 0x07090D), [
                    art(.dial(bind.primary, .fuel), 0.25, 0.52, 0.46, 0.92, needle),
                    text(label, 0.76, 0.26, 0.44, 0.13, .rounded, .bold, 14, grey, .leading),
                    data(bind.primary, 0.76, 0.5, 0.44, 0.3, .rajdhani, .bold, 34, white, .leading),
                    data(second, 0.76, 0.76, 0.44, 0.14, .rounded, .semibold, 15, warm, .leading),
                ])
            }
            return (.spotlight(0x1C2230, 0x07090D), [
                art(.dial(bind.primary, .fuel), 0.5, 0.42, 0.92, 0.72, needle),
                data(bind.primary, 0.5, 0.82, 0.88, 0.17, .rajdhani, .bold, 22, white, .center),
            ])

        case .odometer:
            let red: UInt32 = 0xD92D20, engraved: UInt32 = 0xD7DBE2
            if wide {
                return (.texture(.brushed, 0x2A2D33), [
                    art(.symbol(bind.symbol), 0.08, 0.2, 0.06, 0.16, engraved),
                    text(label, 0.5, 0.2, 0.7, 0.13, .rajdhani, .bold, 16, engraved, .center, shadow: true),
                    art(.odometer(bind.primary), 0.5, 0.5, 0.86, 0.34, red),
                    art(.odometer(second), 0.5, 0.82, 0.56, 0.17, red),
                ])
            }
            return (.texture(.brushed, 0x2A2D33), [
                text(label, 0.5, 0.2, 0.86, 0.13, .rajdhani, .bold, 15, engraved, .center, shadow: true),
                art(.odometer(bind.primary), 0.5, 0.52, 0.92, 0.3, red),
                art(.symbol(bind.symbol), 0.5, 0.82, 0.13, 0.13, engraved, opacity: 0.8),
            ])

        case .highwaySign:
            let green: UInt32 = 0x0B6E3B
            if wide {
                return (.solid(green), [
                    art(.sticker(.signFrame), 0.5, 0.5, 1, 1, white),
                    art(.sticker(.roadArrow), 0.11, 0.5, 0.14, 0.56, white),
                    text(label, 0.45, 0.34, 0.46, 0.2, .system, .bold, 21, white, .leading),
                    data(bind.primary, 0.81, 0.34, 0.27, 0.2, .system, .heavy, 22, white, .trailing),
                    data(second, 0.6, 0.69, 0.74, 0.2, .system, .bold, 18, white, .leading),
                ])
            }
            return (.solid(green), [
                art(.sticker(.signFrame), 0.5, 0.5, 1, 1, white),
                art(.sticker(.roadArrow), 0.5, 0.27, 0.26, 0.28, white),
                text(label, 0.5, 0.56, 0.82, 0.15, .system, .bold, 17, white, .center),
                data(bind.primary, 0.5, 0.77, 0.82, 0.2, .system, .heavy, 24, white, .center),
            ])

        case .leatherStitch:
            let thread: UInt32 = 0xD9A44A, pressed: UInt32 = 0xF1E6D6, tan: UInt32 = 0xC9B39A
            if wide {
                return (.texture(.leather, 0x2E1E16), [
                    art(.sticker(.stitching), 0.5, 0.5, 1, 1, thread),
                    art(.symbol(bind.symbol), 0.14, 0.5, 0.13, 0.34, thread),
                    text(label, 0.58, 0.27, 0.64, 0.14, .rounded, .bold, 14, thread, .leading),
                    data(bind.primary, 0.58, 0.52, 0.64, 0.32, .serif, .bold, 36, pressed, .leading, shadow: true),
                    data(second, 0.58, 0.77, 0.64, 0.14, .rounded, .semibold, 15, tan, .leading),
                ])
            }
            return (.texture(.leather, 0x2E1E16), [
                art(.sticker(.stitching), 0.5, 0.5, 1, 1, thread),
                art(.symbol(bind.symbol), 0.5, 0.27, 0.17, 0.17, thread),
                data(bind.primary, 0.5, 0.58, 0.8, 0.32, .serif, .bold, 30, pressed, .center, shadow: true),
            ])

        case .digitalCockpit:
            let cyan: UInt32 = 0x22D3EE, steel: UInt32 = 0x9FB3C8
            if wide {
                return (.gradient(0x0A1422, 0x02050A), [
                    art(.sticker(.signFrame), 0.5, 0.5, 1, 1, cyan, opacity: 0.3),
                    text(label, 0.3, 0.18, 0.5, 0.12, .rajdhani, .bold, 15, cyan, .leading),
                    data(bind.primary, 0.3, 0.48, 0.5, 0.34, .rajdhani, .bold, 40, white, .leading),
                    art(.progressBar(bind.primary), 0.3, 0.8, 0.5, 0.1, cyan, glow: true, segments: 14),
                    data(second, 0.8, 0.36, 0.32, 0.18, .rajdhani, .semibold, 17, steel, .center),
                    art(.symbol(bind.symbol), 0.69, 0.7, 0.06, 0.15, cyan, glow: true),
                    art(.symbol("gauge.with.dots.needle.33percent"), 0.8, 0.7, 0.06, 0.15, steel),
                    art(.symbol("checkmark.circle.fill"), 0.91, 0.7, 0.06, 0.15, 0x34D399),
                ])
            }
            return (.gradient(0x0A1422, 0x02050A), [
                art(.sticker(.signFrame), 0.5, 0.5, 1, 1, cyan, opacity: 0.3),
                text(label, 0.5, 0.18, 0.8, 0.12, .rajdhani, .bold, 15, cyan, .leading),
                data(bind.primary, 0.5, 0.47, 0.82, 0.32, .rajdhani, .bold, 32, white, .leading),
                art(.progressBar(bind.primary), 0.5, 0.78, 0.8, 0.1, cyan, glow: true, segments: 10),
            ])

        case .headUpDisplay:
            let hud: UInt32 = 0x4ADE80, pale: UInt32 = 0xBBF7D0
            if wide {
                return (.gradient(0x1B2A3A, 0x03060A), [
                    art(.sticker(.hudLines), 0.5, 0.5, 1, 1, hud, opacity: 0.7),
                    data(bind.primary, 0.27, 0.27, 0.46, 0.32, .rajdhani, .bold, 36, hud, .center, glow: true),
                    text(label, 0.75, 0.18, 0.42, 0.13, .rajdhani, .bold, 15, hud, .center, glow: true),
                    data(second, 0.75, 0.32, 0.42, 0.14, .rajdhani, .semibold, 15, pale, .center),
                ])
            }
            return (.gradient(0x1B2A3A, 0x03060A), [
                art(.sticker(.hudLines), 0.5, 0.5, 1, 1, hud, opacity: 0.7),
                text(label, 0.5, 0.12, 0.8, 0.12, .rajdhani, .bold, 14, hud, .center, opacity: 0.85),
                data(bind.primary, 0.5, 0.29, 0.9, 0.26, .rajdhani, .bold, 30, hud, .center, glow: true),
            ])

        case .frostedGlass:
            if wide {
                return (.frosted(0x8B5CF6, 0x06B6D4), [
                    art(.sticker(.glassPanel), 0.32, 0.5, 0.58, 0.84, white),
                    art(.symbol(bind.symbol), 0.11, 0.25, 0.07, 0.17, white),
                    data(bind.primary, 0.32, 0.53, 0.5, 0.32, .rounded, .heavy, 36, white, .leading),
                    text(bind.label, 0.32, 0.78, 0.5, 0.12, .rounded, .semibold, 14, white, .leading, opacity: 0.85),
                    art(.sticker(.glassPanel), 0.81, 0.5, 0.32, 0.84, white),
                    data(second, 0.81, 0.5, 0.26, 0.5, .rounded, .bold, 17, white, .center),
                ])
            }
            return (.frosted(0x8B5CF6, 0x06B6D4), [
                art(.sticker(.glassPanel), 0.5, 0.5, 0.86, 0.86, white),
                art(.symbol(bind.symbol), 0.25, 0.25, 0.15, 0.15, white),
                data(bind.primary, 0.5, 0.55, 0.72, 0.3, .rounded, .heavy, 30, white, .leading),
                text(bind.label, 0.5, 0.78, 0.72, 0.12, .rounded, .semibold, 14, white, .leading, opacity: 0.85),
            ])

        case .liveSky:
            if wide {
                return (.sky, [
                    data(second, 0.3, 0.27, 0.52, 0.14, .rounded, .semibold, 15, white, .leading, shadow: true),
                    data(bind.primary, 0.3, 0.52, 0.52, 0.34, .rounded, .heavy, 40, white, .leading, shadow: true),
                    text(label, 0.3, 0.76, 0.52, 0.12, .rounded, .bold, 14, white, .leading, shadow: true),
                ])
            }
            return (.sky, [
                data(bind.primary, 0.5, 0.6, 0.88, 0.3, .rounded, .heavy, 32, white, .center, shadow: true),
                text(label, 0.5, 0.8, 0.88, 0.12, .rounded, .bold, 14, white, .center, shadow: true),
            ])

        case .boardingPass:
            let paper: UInt32 = 0xF8F4EA, ink: UInt32 = 0x0F172A, muted: UInt32 = 0x55657D, blue: UInt32 = 0x1F4FD8
            if wide {
                return (.solid(paper), [
                    art(.sticker(.ticket), 0.5, 0.5, 1, 1, 0x000000),
                    text("BOARDING PASS", 0.24, 0.14, 0.42, 0.11, .rounded, .heavy, 14, blue, .leading),
                    text("FROM", 0.14, 0.34, 0.22, 0.1, .rounded, .bold, 14, muted, .leading),
                    text("HOME", 0.15, 0.53, 0.24, 0.22, .system, .heavy, 30, ink, .leading),
                    art(.symbol("car.side.fill"), 0.325, 0.53, 0.05, 0.12, blue),
                    text("TO", 0.48, 0.34, 0.2, 0.1, .rounded, .bold, 14, muted, .leading),
                    text("WORK", 0.49, 0.53, 0.24, 0.22, .system, .heavy, 30, ink, .leading),
                    text(label, 0.33, 0.8, 0.6, 0.12, .rounded, .bold, 14, muted, .leading),
                    text("DEPARTS", 0.85, 0.2, 0.24, 0.1, .rounded, .bold, 14, muted, .center),
                    data(bind.primary, 0.85, 0.44, 0.26, 0.24, .rajdhani, .bold, 24, ink, .center),
                ])
            }
            return (.solid(paper), [
                art(.sticker(.ticket), 0.5, 0.5, 1, 1, 0x000000),
                text("DEPARTS", 0.6, 0.18, 0.7, 0.11, .rounded, .bold, 14, muted, .center),
                data(bind.primary, 0.6, 0.42, 0.72, 0.26, .rajdhani, .bold, 28, ink, .center),
                text("HOME → WORK", 0.6, 0.63, 0.74, 0.12, .rounded, .heavy, 14, blue, .center),
            ])

        case .splitFlap:
            let amber: UInt32 = 0xF5B700, grey: UInt32 = 0xB8BEC8
            if wide {
                return (.texture(.brushed, 0x15171B), [
                    art(.symbol(bind.symbol), 0.07, 0.17, 0.06, 0.14, amber),
                    text(label, 0.36, 0.17, 0.5, 0.13, .rounded, .heavy, 14, amber, .leading),
                    data(.clock, 0.86, 0.17, 0.22, 0.13, .mono, .bold, 15, grey, .trailing),
                    art(.splitFlap(bind.primary), 0.5, 0.49, 0.92, 0.32, amber),
                    art(.splitFlap(second), 0.5, 0.81, 0.92, 0.22, amber),
                ])
            }
            return (.texture(.brushed, 0x15171B), [
                text(label, 0.5, 0.19, 0.86, 0.12, .rounded, .heavy, 14, amber, .center),
                art(.splitFlap(bind.primary), 0.5, 0.5, 0.9, 0.34, amber),
                data(second, 0.5, 0.82, 0.86, 0.13, .rounded, .semibold, 14, grey, .center),
            ])

        case .neonSign:
            let pink: UInt32 = 0xFF3FA4, cyan: UInt32 = 0x3DF5FF, yellow: UInt32 = 0xFFE45C
            if wide {
                return (.texture(.brick, 0x3A1F1A), [
                    art(.sticker(.neonTube), 0.5, 0.5, 0.96, 0.9, pink),
                    text(label, 0.34, 0.31, 0.5, 0.16, .rounded, .heavy, 18, pink, .leading, glow: true),
                    data(bind.primary, 0.36, 0.62, 0.54, 0.32, .rounded, .bold, 34, cyan, .leading, glow: true),
                    art(.symbol(bind.symbol), 0.78, 0.33, 0.12, 0.22, yellow, glow: true),
                    data(second, 0.78, 0.65, 0.3, 0.18, .rounded, .semibold, 16, yellow, .center, glow: true),
                ])
            }
            return (.texture(.brick, 0x3A1F1A), [
                art(.sticker(.neonTube), 0.5, 0.5, 0.92, 0.92, pink),
                text(label, 0.5, 0.27, 0.62, 0.13, .rounded, .heavy, 14, pink, .center, glow: true),
                data(bind.primary, 0.5, 0.56, 0.74, 0.34, .rounded, .bold, 28, cyan, .center, glow: true),
            ])

        case .woodTrim:
            let brass: UInt32 = 0xD9B26F, cream: UInt32 = 0xF4E7CB
            if wide {
                return (.texture(.wood, 0x4A2A16), [
                    art(.sticker(.signFrame), 0.5, 0.5, 0.96, 0.9, brass),
                    art(.symbol(bind.symbol), 0.14, 0.5, 0.12, 0.3, brass),
                    text(label, 0.57, 0.27, 0.62, 0.13, .playfair, .regular, 16, brass, .leading),
                    data(bind.primary, 0.57, 0.53, 0.62, 0.3, .playfair, .bold, 36, cream, .leading, shadow: true),
                    data(second, 0.57, 0.77, 0.62, 0.13, .serif, .regular, 15, brass, .leading),
                ])
            }
            return (.texture(.wood, 0x4A2A16), [
                art(.sticker(.signFrame), 0.5, 0.5, 0.92, 0.92, brass),
                text(label, 0.5, 0.26, 0.7, 0.12, .playfair, .regular, 14, brass, .center),
                data(bind.primary, 0.5, 0.53, 0.76, 0.3, .playfair, .bold, 28, cream, .center, shadow: true),
                data(second, 0.5, 0.77, 0.72, 0.12, .serif, .regular, 14, brass, .center),
            ])

        case .carStereo:
            let amber: UInt32 = 0xFFB020, grey: UInt32 = 0xB8BEC8
            if wide {
                return (.texture(.brushed, 0x1C1D20), [
                    art(.sticker(.tuningScale), 0.5, 0.2, 0.9, 0.26, amber),
                    art(.sticker(.lcdPanel), 0.37, 0.65, 0.64, 0.5, amber),
                    data(bind.primary, 0.37, 0.65, 0.56, 0.3, .mono, .bold, 30, amber, .center, glow: true),
                    text(label, 0.85, 0.52, 0.24, 0.14, .rajdhani, .bold, 15, grey, .center),
                    data(second, 0.85, 0.74, 0.24, 0.14, .rajdhani, .semibold, 14, amber, .center),
                ])
            }
            return (.texture(.brushed, 0x1C1D20), [
                text(label, 0.5, 0.17, 0.8, 0.12, .rajdhani, .bold, 14, grey, .center),
                art(.sticker(.lcdPanel), 0.5, 0.5, 0.88, 0.46, amber),
                data(bind.primary, 0.5, 0.5, 0.78, 0.3, .mono, .bold, 24, amber, .center, glow: true),
                data(second, 0.5, 0.84, 0.84, 0.12, .rajdhani, .semibold, 14, grey, .center),
            ])

        case .navigation:
            let blue: UInt32 = 0x3B82F6, muted: UInt32 = 0x93A4C3
            if wide {
                return (.solid(0x1B2130), [
                    art(.sticker(.streetMap), 0.31, 0.5, 0.62, 1, blue),
                    art(.sticker(.roadArrow), 0.81, 0.23, 0.14, 0.28, blue),
                    data(bind.primary, 0.81, 0.55, 0.32, 0.24, .rounded, .bold, 26, white, .center),
                    data(second, 0.81, 0.8, 0.32, 0.13, .rounded, .semibold, 14, muted, .center),
                ])
            }
            return (.solid(0x1B2130), [
                art(.sticker(.streetMap), 0.5, 0.5, 1, 1, blue),
                art(.sticker(.glassPanel), 0.5, 0.84, 0.86, 0.22, white),
                data(bind.primary, 0.5, 0.84, 0.78, 0.17, .rounded, .bold, 20, white, .center, shadow: true),
            ])

        case .rainyWindow:
            let mist: UInt32 = 0xD6E4FF
            if wide {
                return (.rain(0xFF4D6D, 0x3BA7FF), [
                    art(.symbol(bind.symbol), 0.08, 0.24, 0.07, 0.17, white),
                    text(label, 0.38, 0.24, 0.52, 0.13, .rounded, .semibold, 15, mist, .leading, shadow: true),
                    data(.clock, 0.86, 0.24, 0.22, 0.14, .rounded, .semibold, 16, white, .trailing, shadow: true),
                    data(bind.primary, 0.4, 0.56, 0.72, 0.34, .rounded, .bold, 42, white, .leading, shadow: true),
                    data(second, 0.4, 0.83, 0.72, 0.13, .rounded, .semibold, 15, mist, .leading, shadow: true),
                ])
            }
            return (.rain(0xFF4D6D, 0x3BA7FF), [
                text(label, 0.5, 0.22, 0.8, 0.12, .rounded, .semibold, 14, mist, .center, shadow: true),
                data(bind.primary, 0.5, 0.5, 0.86, 0.32, .rounded, .bold, 32, white, .center, shadow: true),
                data(second, 0.5, 0.78, 0.84, 0.12, .rounded, .semibold, 14, mist, .center, shadow: true),
            ])

        case .parkingTicket:
            let paper: UInt32 = 0xFBFAF5, ink: UInt32 = 0x111111, faded: UInt32 = 0x3A3A3A
            if wide {
                // The ticket is turned 4° anticlockwise; text above its centre shifts left, below it right.
                return (.gradient(0xC9CDD3, 0xA7ACB4), [
                    art(.sticker(.thermalTicket), 0.5, 0.5, 0.5, 0.92, paper, rotation: -4),
                    text(label, 0.49, 0.19, 0.42, 0.11, .mono, .bold, 15, ink, .center, rotation: -4),
                    data(bind.primary, 0.5, 0.5, 0.44, 0.26, .mono, .bold, 28, ink, .center, rotation: -4),
                    data(second, 0.51, 0.82, 0.42, 0.11, .mono, .semibold, 14, faded, .center, rotation: -4),
                ])
            }
            return (.gradient(0xC9CDD3, 0xA7ACB4), [
                art(.sticker(.thermalTicket), 0.5, 0.5, 0.82, 0.94, paper),
                text(label, 0.5, 0.18, 0.7, 0.11, .mono, .bold, 14, ink, .center),
                data(bind.primary, 0.5, 0.5, 0.72, 0.26, .mono, .bold, 22, ink, .center),
                data(second, 0.5, 0.82, 0.7, 0.11, .mono, .semibold, 14, faded, .center),
            ])

        case .numberPlate:
            let lilac: UInt32 = 0xC7D2FE
            if wide {
                return (.gradient(0x1E3A8A, 0x0A1430), [
                    art(.sticker(.plateFrame), 0.36, 0.55, 0.62, 0.56, 0x0B0C0F),
                    data(bind.primary, 0.36, 0.58, 0.52, 0.32, .rajdhani, .bold, 36, white, .center),
                    text(label, 0.84, 0.36, 0.28, 0.14, .rounded, .bold, 15, lilac, .center),
                    data(second, 0.84, 0.62, 0.28, 0.14, .rounded, .semibold, 15, white, .center),
                ])
            }
            return (.gradient(0x1E3A8A, 0x0A1430), [
                text(label, 0.5, 0.2, 0.8, 0.12, .rounded, .bold, 14, lilac, .center),
                art(.sticker(.plateFrame), 0.5, 0.55, 0.92, 0.4, 0x0B0C0F),
                data(bind.primary, 0.5, 0.57, 0.78, 0.24, .rajdhani, .bold, 26, white, .center),
                data(second, 0.5, 0.86, 0.84, 0.12, .rounded, .semibold, 14, lilac, .center),
            ])

        case .shiftLight:
            let red: UInt32 = 0xFF3B30, grey: UInt32 = 0xB7BDC7
            if wide {
                return (.texture(.carbon, 0x101215), [
                    art(.shiftLights(bind.primary), 0.5, 0.17, 0.92, 0.16, white),
                    data(bind.primary, 0.33, 0.6, 0.56, 0.4, .rajdhani, .bold, 44, white, .leading),
                    text(label, 0.82, 0.47, 0.3, 0.13, .rajdhani, .bold, 15, red, .center),
                    data(second, 0.82, 0.7, 0.3, 0.14, .rajdhani, .semibold, 15, grey, .center),
                ])
            }
            return (.texture(.carbon, 0x101215), [
                art(.shiftLights(bind.primary), 0.5, 0.2, 0.9, 0.14, white),
                data(bind.primary, 0.5, 0.53, 0.9, 0.34, .rajdhani, .bold, 32, white, .center),
                text(label, 0.5, 0.81, 0.8, 0.12, .rajdhani, .bold, 14, red, .center),
            ])

        case .polaroid:
            let ink: UInt32 = 0x1F1F1F, frame: UInt32 = 0xFBFBF8
            if wide {
                return (.texture(.cork, 0xB7894F), [
                    art(.sticker(.polaroidFrame), 0.3, 0.5, 0.3, 0.9, frame, rotation: -3),
                    DesignLayer(content: .carPhoto, x: 0.3, y: 0.4, width: 0.24, height: 0.5, rotation: -3, colorHex: white),
                    data(bind.primary, 0.3, 0.82, 0.28, 0.14, .rounded, .bold, 16, ink, .center, rotation: -3),
                    art(.sticker(.stickyNote), 0.72, 0.5, 0.36, 0.68, 0xFFE45C, rotation: 4),
                    text(label, 0.72, 0.34, 0.3, 0.13, .rounded, .heavy, 14, ink, .center, rotation: 4),
                    data(second, 0.72, 0.56, 0.3, 0.22, .rounded, .heavy, 18, ink, .center, rotation: 4),
                ])
            }
            return (.texture(.cork, 0xB7894F), [
                art(.sticker(.polaroidFrame), 0.5, 0.5, 0.74, 0.9, frame, rotation: -3),
                DesignLayer(content: .carPhoto, x: 0.5, y: 0.41, width: 0.6, height: 0.5, rotation: -3, colorHex: white),
                data(bind.primary, 0.5, 0.82, 0.64, 0.14, .rounded, .bold, 18, ink, .center, rotation: -3),
            ])

        case .stickyNote:
            let ink: UInt32 = 0x1F1F1F
            if wide {
                return (.texture(.cork, 0xB7894F), [
                    art(.sticker(.stickyNote), 0.27, 0.52, 0.42, 0.8, 0xFFE45C, rotation: -3),
                    text(label, 0.27, 0.32, 0.36, 0.13, .rounded, .heavy, 15, ink, .center, rotation: -3),
                    data(bind.primary, 0.27, 0.6, 0.38, 0.3, .rounded, .heavy, 28, ink, .center, rotation: -3),
                    art(.sticker(.stickyNote), 0.73, 0.5, 0.42, 0.8, 0xFF9BD8, rotation: 3),
                    data(second, 0.73, 0.54, 0.36, 0.34, .rounded, .heavy, 20, ink, .center, rotation: 3),
                ])
            }
            return (.texture(.cork, 0xB7894F), [
                art(.sticker(.stickyNote), 0.5, 0.52, 0.82, 0.8, 0xFFE45C, rotation: -2),
                text(label, 0.5, 0.32, 0.7, 0.13, .rounded, .heavy, 15, ink, .center, rotation: -2),
                data(bind.primary, 0.5, 0.6, 0.72, 0.3, .rounded, .heavy, 28, ink, .center, rotation: -2),
            ])

        case .dotMatrix:
            let amber: UInt32 = 0xFFB020
            if wide {
                return (.solid(0x16181C), [
                    art(.sticker(.dotMatrix), 0.5, 0.5, 0.94, 0.84, amber),
                    data(bind.primary, 0.5, 0.37, 0.86, 0.3, .mono, .bold, 30, amber, .center, glow: true),
                    text(label, 0.28, 0.7, 0.4, 0.18, .mono, .bold, 16, amber, .leading, glow: true),
                    data(second, 0.7, 0.7, 0.42, 0.18, .mono, .bold, 16, amber, .trailing, glow: true),
                ])
            }
            return (.solid(0x16181C), [
                art(.sticker(.dotMatrix), 0.5, 0.5, 0.92, 0.7, amber),
                data(bind.primary, 0.5, 0.5, 0.84, 0.4, .mono, .bold, 24, amber, .center, glow: true),
            ])

        case .chalkboard:
            let chalk: UInt32 = 0xF2F2EA, yellow: UInt32 = 0xF7E27A
            if wide {
                return (.texture(.chalkboard, 0x1F3B2D), [
                    text(label, 0.32, 0.27, 0.56, 0.14, .rounded, .semibold, 16, yellow, .leading),
                    data(bind.primary, 0.32, 0.53, 0.56, 0.32, .rounded, .bold, 38, chalk, .leading),
                    art(.progressBar(nil), 0.26, 0.74, 0.44, 0.03, chalk, opacity: 0.7),
                    art(.symbol(bind.symbol), 0.78, 0.3, 0.12, 0.24, chalk),
                    data(second, 0.78, 0.6, 0.34, 0.2, .rounded, .semibold, 16, yellow, .center),
                ])
            }
            return (.texture(.chalkboard, 0x1F3B2D), [
                text(label, 0.5, 0.25, 0.8, 0.13, .rounded, .semibold, 15, yellow, .center),
                data(bind.primary, 0.5, 0.52, 0.84, 0.3, .rounded, .bold, 30, chalk, .center),
                art(.progressBar(nil), 0.5, 0.73, 0.5, 0.03, chalk, opacity: 0.7),
            ])

        case .thermometer:
            let red: UInt32 = 0xFF3B30, muted: UInt32 = 0x9FB4CC
            if wide {
                return (.gradient(0x0F2740, 0x050B14), [
                    art(.thermometer(bind.primary), 0.12, 0.52, 0.16, 0.86, red),
                    text(label, 0.52, 0.28, 0.6, 0.13, .rounded, .semibold, 15, muted, .leading),
                    data(bind.primary, 0.52, 0.55, 0.6, 0.34, .rounded, .bold, 40, white, .leading),
                    data(second, 0.52, 0.8, 0.6, 0.13, .rounded, .semibold, 14, muted, .leading),
                ])
            }
            return (.gradient(0x0F2740, 0x050B14), [
                art(.thermometer(bind.primary), 0.24, 0.52, 0.3, 0.84, red),
                data(bind.primary, 0.66, 0.46, 0.58, 0.3, .rounded, .bold, 26, white, .center),
                text(label, 0.66, 0.68, 0.58, 0.12, .rounded, .semibold, 14, muted, .center),
            ])

        case .battery:
            let muted: UInt32 = 0x9CA3AF
            if wide {
                return (.gradient(0x111827, 0x030712), [
                    art(.battery(bind.primary), 0.36, 0.5, 0.6, 0.56, white),
                    data(bind.primary, 0.34, 0.5, 0.44, 0.3, .rounded, .heavy, 30, white, .center, shadow: true),
                    text(label, 0.82, 0.36, 0.3, 0.14, .rounded, .bold, 15, muted, .center),
                    data(second, 0.82, 0.62, 0.3, 0.14, .rounded, .semibold, 15, white, .center),
                ])
            }
            return (.gradient(0x111827, 0x030712), [
                text(label, 0.5, 0.17, 0.8, 0.12, .rounded, .bold, 14, muted, .center),
                art(.battery(bind.primary), 0.5, 0.5, 0.84, 0.42, white),
                data(bind.primary, 0.47, 0.5, 0.6, 0.24, .rounded, .heavy, 22, white, .center, shadow: true),
                data(second, 0.5, 0.84, 0.84, 0.12, .rounded, .semibold, 14, muted, .center),
            ])

        case .speedSign:
            let ink: UInt32 = 0x111111, ring: UInt32 = 0xD92D20
            if wide {
                return (.gradient(0xDCE8F2, 0xA9BFD2), [
                    art(.sticker(.speedSign), 0.25, 0.5, 0.44, 0.9, ring),
                    data(bind.primary, 0.25, 0.5, 0.26, 0.3, .system, .heavy, 30, ink, .center),
                    text(label, 0.72, 0.36, 0.46, 0.14, .rounded, .heavy, 16, ink, .center),
                    data(second, 0.72, 0.62, 0.46, 0.14, .rounded, .semibold, 15, 0x1F2937, .center),
                ])
            }
            return (.gradient(0xDCE8F2, 0xA9BFD2), [
                art(.sticker(.speedSign), 0.5, 0.45, 0.78, 0.78, ring),
                data(bind.primary, 0.5, 0.45, 0.5, 0.3, .system, .heavy, 26, ink, .center),
                text(label, 0.5, 0.92, 0.8, 0.1, .rounded, .bold, 14, ink, .center),
            ])

        case .vinyl:
            let lilac: UInt32 = 0xB3A7D9
            if wide {
                return (.gradient(0x1F1B2E, 0x07060B), [
                    art(.sticker(.vinylRecord), 0.24, 0.5, 0.44, 0.92, 0xE5484D),
                    text(label, 0.68, 0.3, 0.58, 0.13, .rounded, .bold, 14, lilac, .leading),
                    data(bind.primary, 0.68, 0.53, 0.58, 0.26, .rounded, .bold, 26, white, .leading),
                    data(second, 0.68, 0.76, 0.58, 0.13, .rounded, .semibold, 14, lilac, .leading),
                ])
            }
            return (.gradient(0x1F1B2E, 0x07060B), [
                art(.sticker(.vinylRecord), 0.5, 0.4, 0.7, 0.7, 0xE5484D),
                data(bind.primary, 0.5, 0.85, 0.9, 0.14, .rounded, .bold, 17, white, .center),
            ])

        case .comicPop:
            let ink: UInt32 = 0x111111
            if wide {
                return (.texture(.halftone, 0xFFD400), [
                    art(.sticker(.comicBurst), 0.32, 0.5, 0.6, 0.96, 0xFF5A36),
                    data(bind.primary, 0.32, 0.52, 0.4, 0.3, .rounded, .heavy, 30, ink, .center),
                    text(label.uppercased() + "!", 0.78, 0.34, 0.38, 0.16, .rounded, .heavy, 20, ink, .center),
                    data(second, 0.78, 0.62, 0.38, 0.14, .rounded, .bold, 15, ink, .center),
                ])
            }
            return (.texture(.halftone, 0xFFD400), [
                art(.sticker(.comicBurst), 0.5, 0.54, 0.94, 0.84, 0xFF5A36),
                text(label.uppercased() + "!", 0.5, 0.36, 0.5, 0.12, .rounded, .heavy, 15, ink, .center),
                data(bind.primary, 0.5, 0.58, 0.62, 0.28, .rounded, .heavy, 26, ink, .center),
            ])

        case .flipClock:
            let amber: UInt32 = 0xF5B700, grey: UInt32 = 0xB8BEC8
            if wide {
                return (.texture(.brushed, 0x15171B), [
                    art(.splitFlap(.clock), 0.5, 0.42, 0.9, 0.5, amber),
                    data(.date, 0.5, 0.84, 0.8, 0.14, .rounded, .semibold, 16, grey, .center),
                ])
            }
            return (.texture(.brushed, 0x15171B), [
                art(.splitFlap(.clock), 0.5, 0.45, 0.92, 0.42, amber),
                data(.date, 0.5, 0.82, 0.86, 0.13, .rounded, .semibold, 15, grey, .center),
            ])

        case .wordClock:
            let lit: UInt32 = 0xFFF4D6, grey: UInt32 = 0x9CA3AF
            if wide {
                return (.solid(0x0A0B0E), [
                    art(.sticker(.letterGrid), 0.5, 0.5, 1, 1, white),
                    data(.timeInWords, 0.5, 0.44, 0.9, 0.5, .rajdhani, .bold, 30, lit, .center, glow: true),
                    data(.date, 0.5, 0.85, 0.8, 0.12, .rounded, .semibold, 14, grey, .center),
                ])
            }
            return (.solid(0x0A0B0E), [
                art(.sticker(.letterGrid), 0.5, 0.5, 1, 1, white),
                data(.timeInWords, 0.5, 0.5, 0.9, 0.6, .rajdhani, .bold, 24, lit, .center, glow: true),
            ])

        case .hijriDate:
            let gold: UInt32 = 0xF5C542
            if wide {
                return (.gradient(0x0B3D2E, 0x04140F), [
                    art(.sticker(.crescent), 0.14, 0.5, 0.2, 0.6, gold),
                    data(.hijriDate, 0.64, 0.42, 0.66, 0.3, .playfair, .bold, 28, white, .leading),
                    data(.date, 0.64, 0.72, 0.66, 0.14, .rounded, .semibold, 16, gold, .leading),
                ])
            }
            return (.gradient(0x0B3D2E, 0x04140F), [
                art(.sticker(.crescent), 0.5, 0.23, 0.3, 0.3, gold),
                data(.hijriDate, 0.5, 0.56, 0.9, 0.26, .playfair, .bold, 20, white, .center),
                data(.date, 0.5, 0.82, 0.86, 0.12, .rounded, .semibold, 14, gold, .center),
            ])

        case .moonPhase:
            let moon: UInt32 = 0xF4F1E6, mist: UInt32 = 0xDCE6FF
            if wide {
                return (.gradient(0x0B1026, 0x02030A), [
                    art(.sticker(.starfield), 0.5, 0.5, 1, 1, white, opacity: 0.8),
                    art(.moonPhase, 0.22, 0.5, 0.36, 0.8, moon),
                    text("TONIGHT'S MOON", 0.71, 0.33, 0.52, 0.13, .rounded, .bold, 14, mist, .leading),
                    data(.moonPhaseName, 0.71, 0.56, 0.52, 0.24, .rounded, .bold, 26, white, .leading),
                ])
            }
            return (.gradient(0x0B1026, 0x02030A), [
                art(.sticker(.starfield), 0.5, 0.5, 1, 1, white, opacity: 0.8),
                art(.moonPhase, 0.5, 0.42, 0.62, 0.62, moon),
                data(.moonPhaseName, 0.5, 0.86, 0.9, 0.13, .rounded, .semibold, 15, mist, .center),
            ])

        default:
            return (.solid(0x000000), [])
        }
    }

    /// The Phase 17 and 18 Hero templates (spec §3 Panorama hero), on the panorama canvas. Text stays inside
    /// one column (centres 0.16, 0.5 and 0.84, about 0.32 wide) so the gaps never cut it.
    static func hero(_ style: TemplateStyle) -> (DesignBackground, [DesignLayer]) {
        let white: UInt32 = 0xFFFFFF
        let left = 0.16, mid = 0.5, right = 0.84, col = 0.28
        func data(_ field: DataField, _ x: Double, _ y: Double, _ h: Double, _ font: DesignFont, _ weight: DesignWeight, _ size: Double,
                  _ color: UInt32, w: Double = col, shadow: Bool = true, glow: Bool? = nil) -> DesignLayer {
            DesignLayer(content: .data(field), x: x, y: y, width: w, height: h, font: font, weight: weight, fontSize: size,
                        colorHex: color, alignment: .center, shadow: shadow, glow: glow)
        }
        func text(_ string: String, _ x: Double, _ y: Double, _ h: Double, _ size: Double, _ color: UInt32) -> DesignLayer {
            DesignLayer(content: .text(string), x: x, y: y, width: col, height: h, font: .rajdhani, weight: .bold, fontSize: size,
                        colorHex: color, alignment: .center)
        }
        func art(_ content: LayerContent, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: UInt32, opacity: Double = 1) -> DesignLayer {
            DesignLayer(content: content, x: x, y: y, width: w, height: h, opacity: opacity, colorHex: color)
        }
        let car = DesignLayer(content: .carPhoto, x: mid, y: 0.68, width: 0.3, height: 0.44, colorHex: white)

        switch style {
        case .heroSunsetRoad:
            let peach: UInt32 = 0xFFE8D6
            return (.gradient(0xFF9A4D, 0x3B1466), [
                art(.sticker(.sun), mid, 0.4, 0.3, 0.46, 0xFFD166),
                art(.sticker(.road), mid, 0.82, 0.56, 0.36, 0xFFE8A3),
                car,
                data(.clock, left, 0.17, 0.17, .rounded, .heavy, 26, white),
                data(.date, left, 0.32, 0.1, .rounded, .semibold, 14, peach),
                data(.temperature, right, 0.17, 0.17, .rounded, .heavy, 26, white),
                data(.weatherPlace, right, 0.32, 0.1, .rounded, .semibold, 14, peach),
            ])

        case .heroNightCity:
            let moonlight: UInt32 = 0xFFF1C1
            return (.gradient(0x1B2A55, 0x05060D), [
                art(.sticker(.starfield), mid, 0.3, 1, 0.6, white, opacity: 0.7),
                art(.sticker(.crescent), mid, 0.15, 0.1, 0.18, moonlight),
                art(.sticker(.skyline), mid, 0.78, 1, 0.48, 0xFFD27A),
                car,
                data(.greeting, left, 0.15, 0.2, .rounded, .bold, 16, white),
                data(.clock, left, 0.35, 0.15, .rounded, .heavy, 24, white),
                data(.date, right, 0.15, 0.12, .rounded, .bold, 16, moonlight),
                data(.temperature, right, 0.33, 0.15, .rounded, .heavy, 24, white),
            ])

        case .heroCockpit:
            let red: UInt32 = 0xFF3B30, orange: UInt32 = 0xFF7A1A, grey: UInt32 = 0xB7BDC7
            return (.texture(.carbon, 0x0E1014), [
                art(.dial(.kmPerLitre, .fuel), left, 0.46, 0.3, 0.64, orange),
                art(.dial(nil, .instrument), mid, 0.48, 0.31, 0.72, red),
                art(.dial(.kmToService, .instrument), right, 0.46, 0.3, 0.64, red),
                data(.kmPerLitre, left, 0.87, 0.12, .rajdhani, .bold, 16, white, shadow: false),
                data(.clock, mid, 0.9, 0.12, .rajdhani, .bold, 16, white, shadow: false),
                data(.kmToService, right, 0.87, 0.12, .rajdhani, .bold, 16, white, shadow: false),
            ])

        case .heroLiveSky:
            return (.sky, [
                car,
                data(.temperature, left, 0.5, 0.18, .rounded, .heavy, 30, white),
                data(.weatherPlace, left, 0.65, 0.1, .rounded, .semibold, 14, white),
                data(.greeting, mid, 0.14, 0.18, .rounded, .bold, 16, white, w: 0.3),
                data(.prayerCountdown, right, 0.5, 0.18, .rounded, .heavy, 28, white),
                data(.nextPrayerName, right, 0.65, 0.1, .rounded, .semibold, 14, white),
            ])

        case .heroNeonGrid:
            let cyan: UInt32 = 0x3DF5FF, pink: UInt32 = 0xFF9BD8
            return (.gradient(0x2A0845, 0x0A0215), [
                art(.sticker(.stripedSun), mid, 0.36, 0.34, 0.58, 0xFF3FA4),
                art(.sticker(.neonGrid), mid, 0.8, 1, 0.4, 0xC026D3),
                car,
                data(.clock, left, 0.2, 0.17, .orbitron, .heavy, 24, cyan, shadow: false, glow: true),
                data(.date, left, 0.37, 0.1, .orbitron, .semibold, 14, pink, shadow: false, glow: true),
                data(.temperature, right, 0.2, 0.17, .orbitron, .heavy, 24, cyan, shadow: false, glow: true),
                data(.weatherPlace, right, 0.37, 0.1, .orbitron, .semibold, 14, pink, shadow: false, glow: true),
            ])

        case .heroGlassInfo:
            let mist: UInt32 = 0xDCE6FF
            var layers: [DesignLayer] = []
            for x in [left, mid, right] {
                layers.append(art(.sticker(.glassPanel), x, 0.5, 0.29, 0.84, white))
            }
            layers += [
                art(.symbol("moon.stars.fill"), left, 0.24, 0.07, 0.14, white),
                data(.nextPrayerName, left, 0.43, 0.12, .rounded, .semibold, 15, mist, w: 0.25, shadow: false),
                data(.prayerCountdown, left, 0.64, 0.18, .rounded, .bold, 26, white, w: 0.25, shadow: false),
                art(.symbol("cloud.sun.fill"), mid, 0.24, 0.07, 0.14, white),
                data(.weatherPlace, mid, 0.43, 0.12, .rounded, .semibold, 14, mist, w: 0.25, shadow: false),
                data(.temperature, mid, 0.64, 0.18, .rounded, .bold, 30, white, w: 0.25, shadow: false),
                art(.symbol("wrench.and.screwdriver.fill"), right, 0.24, 0.07, 0.14, white),
                text("SERVICE", right, 0.43, 0.12, 15, mist),
                data(.kmToService, right, 0.64, 0.18, .rounded, .bold, 24, white, w: 0.25, shadow: false),
            ]
            return (.frosted(0x8B5CF6, 0x06B6D4), layers)

        case .heroGarage:
            let warm: UInt32 = 0xFFE2B8
            return (.texture(.brick, 0x2A1C18), [
                art(.sticker(.lightCone), mid, 0.45, 0.34, 0.9, 0xFFD58A),
                car,
                data(.clock, left, 0.18, 0.17, .rounded, .heavy, 26, white),
                data(.date, left, 0.33, 0.1, .rounded, .semibold, 14, warm),
                data(.temperature, right, 0.18, 0.17, .rounded, .heavy, 26, white),
                data(.weatherPlace, right, 0.33, 0.1, .rounded, .semibold, 14, warm),
            ])

        case .heroCoastal:
            let foam: UInt32 = 0xFFF1E0
            return (.gradient(0xFFB36B, 0x6A3B8F), [
                art(.sticker(.sun), mid, 0.38, 0.26, 0.4, 0xFFE08A),
                art(.sticker(.waves), mid, 0.82, 1, 0.36, 0xFFB36B),
                art(.sticker(.palms), mid, 0.62, 1, 0.76, 0x1A1024),
                DesignLayer(content: .carPhoto, x: mid, y: 0.72, width: 0.3, height: 0.42, colorHex: white),
                data(.greeting, left, 0.15, 0.2, .rounded, .bold, 16, white),
                data(.clock, left, 0.35, 0.15, .rounded, .heavy, 24, white),
                data(.temperature, right, 0.17, 0.17, .rounded, .heavy, 26, white),
                data(.weatherPlace, right, 0.32, 0.1, .rounded, .semibold, 14, foam),
            ])

        case .heroRainCity:
            let mist: UInt32 = 0xD6E4FF
            return (.rain(0xFF4D6D, 0x3BA7FF), [
                car,
                data(.clock, left, 0.18, 0.17, .rounded, .heavy, 26, white),
                data(.date, left, 0.33, 0.1, .rounded, .semibold, 14, mist),
                data(.temperature, right, 0.18, 0.17, .rounded, .heavy, 26, white),
                data(.weatherPlace, right, 0.33, 0.1, .rounded, .semibold, 14, mist),
            ])

        case .heroStartingGrid:
            let grey: UInt32 = 0xB7BDC7
            return (.texture(.carbon, 0x0E1014), [
                art(.sticker(.startLights), mid, 0.14, 0.3, 0.17, 0xFF2A2A),
                art(.sticker(.chequeredStrip), mid, 0.96, 1, 0.08, white),
                DesignLayer(content: .carPhoto, x: mid, y: 0.6, width: 0.3, height: 0.48, colorHex: white),
                text("TIME", left, 0.28, 0.1, 14, grey),
                data(.clock, left, 0.45, 0.2, .rajdhani, .bold, 30, white, shadow: false),
                text("SERVICE", right, 0.28, 0.1, 14, grey),
                data(.kmToService, right, 0.45, 0.2, .rajdhani, .bold, 28, white, shadow: false),
            ])

        case .heroMountainPass:
            return (.gradient(0x9EC9E8, 0x3C5A7A), [
                art(.sticker(.mountains), mid, 0.68, 1, 0.64, 0x24384F),
                art(.sticker(.road), mid, 0.86, 0.5, 0.28, white),
                DesignLayer(content: .carPhoto, x: mid, y: 0.74, width: 0.3, height: 0.4, colorHex: white),
                data(.greeting, left, 0.15, 0.2, .rounded, .bold, 16, white),
                data(.clock, left, 0.35, 0.15, .rounded, .heavy, 24, white),
                data(.temperature, right, 0.17, 0.17, .rounded, .heavy, 26, white),
                data(.weatherPlace, right, 0.32, 0.1, .rounded, .semibold, 14, white),
            ])

        case .heroDepartureBoard:
            let amber: UInt32 = 0xF5B700, grey: UInt32 = 0xB8BEC8
            return (.texture(.brushed, 0x101215), [
                text("PRAYER", left, 0.18, 0.1, 15, amber),
                art(.splitFlap(.nextPrayerName), left, 0.44, 0.29, 0.2, amber),
                art(.splitFlap(.nextPrayerTime), left, 0.72, 0.29, 0.2, amber),
                text("WEATHER", mid, 0.18, 0.1, 15, amber),
                art(.splitFlap(.temperature), mid, 0.44, 0.29, 0.2, amber),
                data(.weatherPlace, mid, 0.72, 0.12, .rounded, .semibold, 14, grey, shadow: false),
                text("SERVICE", right, 0.18, 0.1, 15, amber),
                art(.splitFlap(.kmToService), right, 0.44, 0.29, 0.2, amber),
                data(.serviceItem, right, 0.72, 0.12, .rounded, .semibold, 14, grey, shadow: false),
            ])

        default:
            return (.solid(0x000000), [])
        }
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
