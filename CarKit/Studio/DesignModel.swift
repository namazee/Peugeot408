import Foundation

// Studio designs: a versioned Codable model, stored as JSON in the App Group and rendered by
// `DesignView` in both the builder and the widget, so the two always look the same.

/// The two canvases a design is built for (CarPlay small and medium).
public enum DesignCanvas: String, Codable, Sendable, CaseIterable {
    case small
    case medium

    /// Width ÷ height of the widget (systemSmall 170×170, systemMedium 364×170 points).
    public var aspectRatio: Double { self == .small ? 1 : 364.0 / 170.0 }

    /// Reference height in points: font sizes are stored at this height and scale with the widget.
    public static let referenceHeight = 170.0

    public var displayName: String { self == .small ? "Small" : "Medium" }
}

/// Fonts offered in the builder: system designs plus the bundled OFL fonts (ASSETS-LICENSES.md).
public enum DesignFont: String, Codable, Sendable, CaseIterable {
    case system
    case rounded
    case serif
    case mono
    case orbitron
    case playfair
    case rajdhani

    public var displayName: String {
        switch self {
        case .system: "SF Pro"
        case .rounded: "SF Rounded"
        case .serif: "New York"
        case .mono: "SF Mono"
        case .orbitron: "Orbitron"
        case .playfair: "Playfair Display"
        case .rajdhani: "Rajdhani"
        }
    }
}

public enum DesignWeight: String, Codable, Sendable, CaseIterable {
    case regular, medium, semibold, bold, heavy
}

public enum DesignAlignment: String, Codable, Sendable, CaseIterable {
    case leading, center, trailing
}

/// Values a data layer can show (any value from spec §4).
public enum DataField: String, Codable, Sendable, CaseIterable, Identifiable {
    case nextPrayerName
    case nextPrayerTime
    case prayerCountdown
    case iftarCountdown
    case serviceItem
    case kmToService
    case daysToService
    case kmPerLitre
    case fuelSpendMonth
    case lastFuelPrice
    case tngBalance
    case daysToRoadTax
    case nearestRenewal
    case parkingPlace
    case parkingTime
    case temperature
    case rainToday
    case airQuality
    case commuteTime
    case nextEvent
    case clock
    case date
    case dayCounter
    case countdownDays
    case musicTitle
    case boost
    case coolantTemp
    case batteryVoltage
    case engineRPM

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .nextPrayerName: "Next prayer"
        case .nextPrayerTime: "Next prayer time"
        case .prayerCountdown: "Prayer countdown"
        case .iftarCountdown: "Iftar countdown (Maghrib)"
        case .serviceItem: "Next service item"
        case .kmToService: "km to service"
        case .daysToService: "Days to service"
        case .kmPerLitre: "km/L"
        case .fuelSpendMonth: "Fuel RM this month"
        case .lastFuelPrice: "Last price per litre"
        case .tngBalance: "TnG balance"
        case .daysToRoadTax: "Days to road tax"
        case .nearestRenewal: "Nearest renewal"
        case .parkingPlace: "Parking place"
        case .parkingTime: "Parked … ago"
        case .temperature: "Temperature"
        case .rainToday: "Rain today"
        case .airQuality: "Haze (API)"
        case .commuteTime: "Drive time"
        case .nextEvent: "Next event"
        case .clock: "Clock"
        case .date: "Date"
        case .dayCounter: "Days since (anniversary)"
        case .countdownDays: "Days until (event)"
        case .musicTitle: "Music title"
        case .boost: "Boost (OBD2)"
        case .coolantTemp: "Coolant (OBD2)"
        case .batteryVoltage: "Battery voltage (OBD2)"
        case .engineRPM: "RPM (OBD2)"
        }
    }

    /// The data source whose timeline dates matter for this field.
    public var source: DataSource? {
        switch self {
        case .nextPrayerName, .nextPrayerTime, .prayerCountdown, .iftarCountdown: .prayer
        case .serviceItem, .kmToService, .daysToService: .service
        case .kmPerLitre, .fuelSpendMonth, .lastFuelPrice: .fuel
        case .tngBalance: .tng
        case .daysToRoadTax, .nearestRenewal: .renewals
        case .parkingPlace, .parkingTime: .parking
        case .temperature, .rainToday, .airQuality: .weather
        case .commuteTime, .nextEvent: .commute
        case .musicTitle: .music
        case .boost, .coolantTemp, .batteryVoltage, .engineRPM: .obd
        case .clock, .date, .dayCounter, .countdownDays: nil
        }
    }
}

/// Original drawn artwork (seasonal packs and stickers). See `Artwork.swift`.
public enum ArtworkKind: String, Codable, Sendable, CaseIterable {
    case ketupat
    case crescent
    case lantern
    case pelita
    case diya
    case stripes
    case tree
    case fireworks
    case gaugeArc
    case speedLines
    case heart
    case star
    case flag

    public var displayName: String {
        switch self {
        case .ketupat: "Ketupat"
        case .crescent: "Crescent & star"
        case .lantern: "Red lantern"
        case .pelita: "Pelita lamps"
        case .diya: "Diya"
        case .stripes: "Stripes"
        case .tree: "Festive tree"
        case .fireworks: "Fireworks"
        case .gaugeArc: "Gauge arc"
        case .speedLines: "Speed lines"
        case .heart: "Heart"
        case .star: "Sparkle"
        case .flag: "Chequered flag"
        }
    }

    /// Shown in the sticker picker (the rest are used by seasonal packs and templates).
    public static let stickers: [ArtworkKind] = [.ketupat, .crescent, .lantern, .diya, .tree, .fireworks, .heart, .star, .flag, .speedLines]
}

/// What a layer draws.
public enum LayerContent: Codable, Sendable, Equatable, Hashable {
    case text(String)
    case symbol(String)
    case sticker(ArtworkKind)
    /// The "My Car" cut-out photo.
    case carPhoto
    case data(DataField)
    /// A gauge arc filled by a field's progress (e.g. km to service); `nil` draws a full decorative arc.
    case gauge(DataField?)
    case analogClock
    /// A number-plate style label.
    case plate(String)
}

/// One layer. Position and size are fractions of the canvas (0…1), so a design scales to any widget.
public struct DesignLayer: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var content: LayerContent
    /// Centre of the layer.
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rotation: Double
    public var opacity: Double
    public var font: DesignFont
    public var weight: DesignWeight
    /// Points at the reference height (170 pt).
    public var fontSize: Double
    public var colorHex: UInt32
    public var alignment: DesignAlignment
    public var shadow: Bool
    public var locked: Bool
    /// Optional short label for data layers ("km to service").
    public var caption: String?

    public init(
        id: UUID = UUID(),
        content: LayerContent,
        x: Double = 0.5, y: Double = 0.5, width: Double = 0.8, height: Double = 0.25,
        rotation: Double = 0, opacity: Double = 1,
        font: DesignFont = .rounded, weight: DesignWeight = .bold, fontSize: Double = 28,
        colorHex: UInt32 = 0xFFFFFF, alignment: DesignAlignment = .leading,
        shadow: Bool = false, locked: Bool = false, caption: String? = nil
    ) {
        self.id = id
        self.content = content
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
        self.opacity = opacity
        self.font = font
        self.weight = weight
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.alignment = alignment
        self.shadow = shadow
        self.locked = locked
        self.caption = caption
    }

    public var dataField: DataField? {
        switch content {
        case .data(let field): field
        case .gauge(let field): field
        default: nil
        }
    }

    public var isText: Bool {
        switch content {
        case .text, .data, .plate: true
        default: false
        }
    }
}

public enum DesignTexture: String, Codable, Sendable, CaseIterable {
    case carbon
    case brushed
    case dots

    public var displayName: String { rawValue.capitalized }
}

public enum DesignBackground: Codable, Sendable, Equatable, Hashable {
    case solid(UInt32)
    case gradient(UInt32, UInt32)
    case texture(DesignTexture, UInt32)
    /// A photo from the Photo Frame library (file name in the photos folder).
    case photo(String)

    /// Approximate colour behind the text, for the contrast check (nil for photos: unknown).
    public var approximateHex: UInt32? {
        switch self {
        case .solid(let hex): hex
        case .gradient(let a, let b): ColorMath.mix(a, b)
        case .texture(_, let hex): hex
        case .photo: nil
        }
    }
}

/// Occasions for the Malaysian seasonal packs (see `Seasonal.swift`).
public enum SeasonalOccasion: String, Codable, Sendable, CaseIterable, Identifiable {
    case ramadan
    case hariRaya
    case aidiladha
    case merdeka
    case chineseNewYear
    case deepavali
    case christmas
    case newYear

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ramadan: "Ramadan"
        case .hariRaya: "Hari Raya Aidilfitri"
        case .aidiladha: "Hari Raya Aidiladha"
        case .merdeka: "Merdeka & Malaysia Day"
        case .chineseNewYear: "Chinese New Year"
        case .deepavali: "Deepavali"
        case .christmas: "Christmas"
        case .newYear: "New Year"
        }
    }
}

/// A saved design.
public struct CardDesign: Codable, Sendable, Equatable, Hashable, Identifiable {
    public static let currentVersion = 1
    /// Spec: at most 2 data fields on the small size.
    public static let maxSmallDataFields = 2

    public var version: Int
    public var id: UUID
    public var name: String
    public var canvas: DesignCanvas
    public var background: DesignBackground
    public var layers: [DesignLayer]
    /// Template it started from, if any (gallery label only).
    public var template: String?
    /// For the Anniversary / Countdown fields: the date counted from or to.
    public var eventDate: Date?
    public var updatedAt: Date

    public init(
        version: Int = CardDesign.currentVersion,
        id: UUID = UUID(),
        name: String,
        canvas: DesignCanvas = .small,
        background: DesignBackground = .gradient(Theme.Hex.surface, Theme.Hex.background),
        layers: [DesignLayer] = [],
        template: String? = nil,
        eventDate: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.version = version
        self.id = id
        self.name = name
        self.canvas = canvas
        self.background = background
        self.layers = layers
        self.template = template
        self.eventDate = eventDate
        self.updatedAt = updatedAt
    }

    public var dataFields: [DataField] { layers.compactMap(\.dataField) }

    /// Sources whose data this design shows (for timeline dates and widget reloads).
    public var sources: Set<DataSource> { Set(dataFields.compactMap(\.source)) }

    /// JSON for export/backup.
    public func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Imports a design file. A fresh id is assigned so it never overwrites an existing design.
    public static func importing(_ data: Data) throws -> CardDesign {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var design = try decoder.decode(CardDesign.self, from: data)
        guard design.version <= currentVersion else { throw StudioError.newerVersion(design.version) }
        design.id = UUID()
        for index in design.layers.indices { design.layers[index].id = UUID() }
        return design
    }
}

public enum StudioError: Error, LocalizedError, Equatable {
    case newerVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .newerVersion(let version): "This design was made by a newer version of the app (format \(version))."
        }
    }
}

/// Seasonal pack settings.
public struct SeasonalSettings: Codable, Sendable, Equatable {
    /// Switch a slot to the seasonal design automatically on the right dates.
    public var enabled: Bool
    /// The Car Slot that is taken over (1–5).
    public var slot: Int
    public var disabled: Set<SeasonalOccasion>
    /// Deepavali follows the Hindu calendar, so its dates come from a table you can correct: year → "yyyy-MM-dd".
    public var deepavaliDates: [Int: String]

    public init(enabled: Bool = false, slot: Int = 1, disabled: Set<SeasonalOccasion> = [], deepavaliDates: [Int: String] = SeasonalCalendar.defaultDeepavali) {
        self.enabled = enabled
        self.slot = slot
        self.disabled = disabled
        self.deepavaliDates = deepavaliDates
    }
}

/// `studio.json`: saved designs, the seasonal settings and the My Car photo.
public struct StudioState: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var designs: [CardDesign]
    public var seasonal: SeasonalSettings
    /// File name of the cut-out car photo (transparent PNG) in the App Group.
    public var carPhotoFile: String?
    /// Number-plate text for the My Car template, e.g. "VKL 408".
    public var plateText: String

    public init(version: Int = StudioState.currentVersion, designs: [CardDesign] = [], seasonal: SeasonalSettings = SeasonalSettings(), carPhotoFile: String? = nil, plateText: String = "") {
        self.version = version
        self.designs = designs
        self.seasonal = seasonal
        self.carPhotoFile = carPhotoFile
        self.plateText = plateText
    }

    public static let empty = StudioState()

    public func design(_ id: UUID?) -> CardDesign? {
        guard let id else { return nil }
        return designs.first { $0.id == id }
    }

    public static let carPhotoFileName = "mycar.png"
}

public enum StudioStores {
    public static func studio(in directory: URL = AppGroup.containerURL) -> JSONFileStore<StudioState> {
        JSONFileStore(directory: directory, fileName: "studio.json") { .empty }
    }
}

/// Colour helpers for hex values (no SwiftUI needed, so tests can use them).
public enum ColorMath {
    public static func components(_ hex: UInt32) -> (r: Double, g: Double, b: Double) {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    public static func mix(_ a: UInt32, _ b: UInt32) -> UInt32 {
        let x = components(a), y = components(b)
        func channel(_ p: Double, _ q: Double) -> UInt32 { UInt32(((p + q) / 2 * 255).rounded()) }
        return channel(x.r, y.r) << 16 | channel(x.g, y.g) << 8 | channel(x.b, y.b)
    }

    /// WCAG 2.1 relative luminance.
    public static func luminance(_ hex: UInt32) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let c = components(hex)
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    /// WCAG contrast ratio, 1…21.
    public static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
