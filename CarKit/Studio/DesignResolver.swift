import Foundation

/// A data field's value at one moment.
public struct ResolvedField: Sendable, Equatable, Hashable {
    public enum Style: Sendable, Equatable, Hashable {
        case plain
        /// Live count-up from `date` (`Text(date, style: .timer)`), e.g. the clock.
        case timer(Date)
        /// Live countdown to `date` that stops at 0:00 (prayer and iftar).
        case countdown(Date)
        /// Live relative text ("2 hr, 14 min").
        case relative(Date)
    }

    public var text: String
    public var style: Style
    /// 0…1 for gauge layers (e.g. how much of the service interval is used).
    public var progress: Double?
    /// State colour for `.stateColor` backgrounds (amber / red / AQI band); nil when all is well.
    public var stateHex: UInt32?

    public init(text: String, style: Style = .plain, progress: Double? = nil, stateHex: UInt32? = nil) {
        self.text = text
        self.style = style
        self.progress = progress
        self.stateHex = stateHex
    }
}

/// A design with its data resolved for one timeline entry: everything `DesignView` needs.
public struct StudioCard: Sendable, Equatable {
    /// The state colour of the first data field that has one (for `.stateColor` backgrounds).
    public var stateHex: UInt32? {
        design.dataFields.lazy.compactMap { values[$0]?.stateHex }.first
    }

    public var design: CardDesign
    public var date: Date
    public var values: [DataField: ResolvedField]
    /// Folder holding the car photo and the photos used as backgrounds.
    public var directory: URL?
    public var carPhotoFile: String?
    public var plateText: String
    public var plateFont: PlateFont
    /// Sunrise and sunset for a Live Sky background (nil for other backgrounds).
    public var sun: SunTimes?

    public init(design: CardDesign, date: Date, values: [DataField: ResolvedField], directory: URL?, carPhotoFile: String?, plateText: String,
                plateFont: PlateFont = .classic, sun: SunTimes? = nil) {
        self.sun = sun
        self.design = design
        self.date = date
        self.values = values
        self.directory = directory
        self.carPhotoFile = carPhotoFile
        self.plateText = plateText
        self.plateFont = plateFont
    }

    public var carPhotoPath: String? {
        guard let carPhotoFile, let directory else { return nil }
        return directory.appending(path: carPhotoFile, directoryHint: .notDirectory).path(percentEncoded: false)
    }

    public func photoPath(_ file: String) -> String? {
        directory.map { MediaStores.photosFolder(in: $0).appending(path: file, directoryHint: .notDirectory).path(percentEncoded: false) }
    }
}

public enum DesignResolver {
    public static func card(for design: CardDesign, data: CarData, studio: StudioState, at date: Date, calendar: Calendar = .current) -> StudioCard {
        var values: [DataField: ResolvedField] = [:]
        for field in Set(design.dataFields) {
            values[field] = field == .greeting
                ? ResolvedField(text: greetingText(at: date, name: studio.ownerName, malay: studio.greetingMalay == true, calendar: calendar))
                : resolve(field, data: data, design: design, at: date, calendar: calendar)
        }
        let sun = design.background == .sky ? Sky.sunTimes(on: date, prayerDays: data.prayer.days, calendar: calendar) : nil
        return StudioCard(design: design, date: date, values: values, directory: data.directory, carPhotoFile: studio.carPhotoFile,
                          plateText: studio.plateText, plateFont: studio.plateFont ?? .classic, sun: sun)
    }

    /// Entry dates for a design: its fields' sources, plus every minute for the next hour if it has an analogue clock.
    public static func dates(for design: CardDesign, data: CarData, from start: Date, calendar: Calendar = .current) -> [Date] {
        var dates = Set<Date>()
        for source in design.sources {
            dates.formUnion(DataTimeline.dates(for: source, data: data, from: start, calendar: calendar))
        }
        dates.formUnion(DayMath.refreshDates(from: start, days: 2, calendar: calendar))
        if design.dataFields.contains(.greeting) {
            dates.formUnion(SlotTimeline.hourBoundaries([5, 12, 15, 18, 19], from: start, calendar: calendar))
        }
        if design.background == .sky {
            dates.formUnion(Sky.changeDates(from: start, prayerDays: data.prayer.days, calendar: calendar))
        }
        if design.dataFields.contains(.timeInWords) {
            dates.formUnion(WordClock.changeDates(from: start, count: 72, calendar: calendar))
        }
        if design.layers.contains(where: { $0.content == .analogClock }) {
            let minute = calendar.dateInterval(of: .minute, for: start)?.start ?? start
            for offset in 1...60 { dates.insert(minute.addingTimeInterval(Double(offset) * 60)) }
        }
        return [start] + dates.filter { $0 > start }.sorted().prefix(70)
    }

    public static func resolve(_ field: DataField, data: CarData, design: CardDesign, at date: Date, calendar: Calendar = .current,
                               studioName: String? = nil, studioMalay: Bool = false) -> ResolvedField {
        func card(_ source: DataSource) -> DataCard { data.card(for: source, at: date, calendar: calendar) }
        let time = Date.FormatStyle(date: .omitted, time: .shortened)

        switch field {
        case .nextPrayerName, .nextPrayerTime, .prayerCountdown:
            guard case .prayer(let s) = card(.prayer), let next = s.next else { return ResolvedField(text: "--") }
            switch field {
            case .nextPrayerName: return ResolvedField(text: next.prayer.displayName)
            case .nextPrayerTime: return ResolvedField(text: next.time.formatted(time))
            default: return ResolvedField(text: "", style: .countdown(next.time))
            }

        case .iftarCountdown:
            let days = data.prayer.days
            guard let today = PrayerSchedule.day(containing: date, in: days) else { return ResolvedField(text: "--") }
            if today.maghrib > date { return ResolvedField(text: "", style: .countdown(today.maghrib)) }
            return ResolvedField(text: "Selamat berbuka")

        case .serviceItem, .kmToService, .daysToService:
            guard case .service(let s) = card(.service), let line = s.lines.first else { return ResolvedField(text: "--") }
            let progress = serviceProgress(data: data, at: date, calendar: calendar)
            let state = stateHex(line.urgency)
            switch field {
            case .serviceItem: return ResolvedField(text: line.name, progress: progress, stateHex: state)
            case .kmToService: return ResolvedField(text: line.kmLeft.map { CarFormat.km($0) } ?? "--", progress: progress, stateHex: state)
            default: return ResolvedField(text: line.daysLeft.map { CarFormat.days($0) } ?? "--", progress: progress, stateHex: state)
            }

        case .kmPerLitre, .fuelSpendMonth, .lastFuelPrice:
            guard case .fuel(let s) = card(.fuel) else { return ResolvedField(text: "--") }
            switch field {
            case .kmPerLitre:
                let value = s.averageKmPerLitre
                return ResolvedField(text: value.map(CarFormat.kmPerLitre) ?? "--", progress: value.map { min(max($0 / 20, 0), 1) })
            case .fuelSpendMonth: return ResolvedField(text: CarFormat.rm(s.spentThisMonth, decimals: 0))
            default: return ResolvedField(text: s.lastPricePerLitre.map { "\(CarFormat.rm($0))/L" } ?? "--")
            }

        case .tngBalance:
            guard case .tng(let s) = card(.tng), let balance = s.balance else { return ResolvedField(text: "--") }
            return ResolvedField(text: CarFormat.rm(balance), progress: min(balance / max(s.threshold * 5, 1), 1), stateHex: s.isLow ? Theme.Hex.dueSoon : nil)

        case .daysToRoadTax:
            let roadTax = data.renewals.items.filter { $0.kind == .roadTax }.min { $0.expiry < $1.expiry }
            guard let roadTax else { return ResolvedField(text: "--") }
            let days = RenewalRules.daysLeft(until: roadTax.expiry, from: date, calendar: calendar)
            return ResolvedField(text: CarFormat.days(days), progress: 1 - min(max(Double(days) / 365, 0), 1), stateHex: stateHex(RenewalRules.urgency(daysLeft: days)))

        case .nearestRenewal:
            guard case .renewals(let s) = card(.renewals), let line = s.lines.first else { return ResolvedField(text: "--") }
            return ResolvedField(text: "\(line.name) \(line.countText) \(line.unitText)", stateHex: stateHex(line.urgency))

        case .parkingPlace:
            guard let spot = data.parking.spot else { return ResolvedField(text: "Not parked") }
            let detail = spot.detailLine
            return ResolvedField(text: detail.isEmpty ? spot.title : "\(spot.title) · \(detail)")

        case .parkingTime:
            guard let spot = data.parking.spot else { return ResolvedField(text: "--") }
            return ResolvedField(text: "", style: .relative(spot.savedAt))

        case .temperature, .rainToday, .airQuality:
            guard case .weather(let s) = card(.weather) else { return ResolvedField(text: "--") }
            switch field {
            case .temperature: return ResolvedField(text: s.temperatureText)
            case .rainToday: return ResolvedField(text: s.rainText ?? "--")
            default: return ResolvedField(text: s.air.map { "API \($0.value)" } ?? "--", progress: s.air.map { min(Double($0.value) / 300, 1) }, stateHex: s.air?.band.hex)
            }

        case .commuteTime:
            guard case .commute(let s) = card(.commute), let destination = s.destination else { return ResolvedField(text: "--") }
            return ResolvedField(text: "\(destination.title.replacingOccurrences(of: "To ", with: "")) \(s.travelText)")

        case .nextEvent:
            guard let event = data.calendar.nextEvent(at: date) else { return ResolvedField(text: "No events") }
            return ResolvedField(text: "\(event.start.formatted(time)) \(event.title)")

        case .clock:
            // Counts up from midnight: reads as a live 24-hour clock with seconds.
            return ResolvedField(text: date.formatted(time), style: .timer(calendar.startOfDay(for: date)))

        case .date:
            return ResolvedField(text: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))

        case .dayCounter:
            guard let event = design.eventDate else { return ResolvedField(text: "Set a date") }
            return ResolvedField(text: anniversaryText(from: event, to: date, calendar: calendar))

        case .greeting:
            return ResolvedField(text: greetingText(at: date, name: studioName, malay: studioMalay, calendar: calendar))

        case .weatherPlace:
            guard case .weather(let s) = card(.weather) else { return ResolvedField(text: "--") }
            let parts = [s.placeLabel, s.condition].compactMap { $0 }.filter { !$0.isEmpty && $0 != "Current location" }
            return ResolvedField(text: parts.isEmpty ? (s.condition ?? "--") : parts.joined(separator: " · "))

        case .weekday:
            return ResolvedField(text: date.formatted(.dateTime.weekday(.wide)).uppercased())

        case .timeInWords:
            return ResolvedField(text: WordClock.text(at: date, calendar: calendar))

        case .hijriDate:
            return ResolvedField(text: HijriDate.text(at: date, timeZone: calendar.timeZone))

        case .moonPhaseName:
            return ResolvedField(text: MoonPhase.name(at: date), progress: MoonPhase.fraction(at: date))

        case .dayOfMonth:
            return ResolvedField(text: "\(calendar.component(.day, from: date))")

        case .monthName:
            return ResolvedField(text: date.formatted(.dateTime.month(.wide).year()).uppercased())

        case .yearProgress:
            let fraction = yearFraction(at: date, calendar: calendar)
            return ResolvedField(text: "\(Int((fraction * 100).rounded(.down)))%", progress: fraction)

        case .countdownDays:
            guard let event = design.eventDate else { return ResolvedField(text: "Set a date") }
            let days = DayMath.days(from: date, to: event, calendar: calendar)
            return ResolvedField(text: days >= 0 ? CarFormat.days(days) : "\(CarFormat.days(-days)) ago")

        case .musicTitle:
            guard case .music(let s) = card(.music) else { return ResolvedField(text: "--") }
            return ResolvedField(text: s.title ?? "--")

        case .boost, .coolantTemp, .batteryVoltage, .engineRPM:
            guard let reading = data.obd.last else { return ResolvedField(text: "--") }
            switch field {
            case .boost:
                return ResolvedField(text: reading.text(.boost), progress: reading.boostBar.map { min(max(($0 + 1) / 2.5, 0), 1) })
            case .coolantTemp:
                return ResolvedField(text: reading.text(.coolant), progress: reading.coolantC.map { min(max(Double($0 - 40) / 80, 0), 1) })
            case .batteryVoltage:
                return ResolvedField(text: reading.text(.voltage), progress: reading.voltage.map { min(max(($0 - 11) / 4, 0), 1) })
            default:
                return ResolvedField(text: reading.text(.rpm), progress: reading.rpm.map { min(Double($0) / 6_500, 1) })
            }
        }
    }

    /// "9 years, 213 days" since `start` (whole years, then remaining days).
    public static func anniversaryText(from start: Date, to date: Date, calendar: Calendar = .current) -> String {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: date)
        guard to >= from else { return "\(CarFormat.days(DayMath.days(from: to, to: from, calendar: calendar))) to go" }
        let years = calendar.dateComponents([.year], from: from, to: to).year ?? 0
        let lastAnniversary = calendar.date(byAdding: .year, value: years, to: from) ?? from
        let days = DayMath.days(from: lastAnniversary, to: to, calendar: calendar)
        switch (years, days) {
        case (0, _): return CarFormat.days(days)
        case (_, 0): return years == 1 ? "1 year" : "\(years) years"
        default: return "\(years == 1 ? "1 year" : "\(years) years"), \(CarFormat.days(days))"
        }
    }

    /// "Good morning, Namazee" / "Selamat petang, Namazee" (no name: just the greeting).
    public static func greetingText(at date: Date, name: String?, malay: Bool, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let line: String = switch (malay, hour) {
        case (false, 5..<12): "Good morning"
        case (false, 12..<18): "Good afternoon"
        case (false, _): "Good evening"
        case (true, 5..<12): "Selamat pagi"
        case (true, 12..<15): "Selamat tengah hari"
        case (true, 15..<19): "Selamat petang"
        case (true, _): "Selamat malam"
        }
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? line : "\(line), \(trimmed)"
    }

    /// Amber / red for due soon / overdue, nil when fine.
    static func stateHex(_ urgency: Urgency) -> UInt32? {
        switch urgency {
        case .ok: nil
        case .dueSoon: Theme.Hex.dueSoon
        case .urgent: Theme.Hex.overdue
        }
    }

    /// How much of this calendar year has passed (0…1).
    public static func yearFraction(at date: Date, calendar: Calendar = .current) -> Double {
        guard let year = calendar.dateInterval(of: .year, for: date) else { return 0 }
        return min(max(date.timeIntervalSince(year.start) / year.duration, 0), 1)
    }

    /// Share of the most urgent service interval used (km-based when known).
    static func serviceProgress(data: CarData, at date: Date, calendar: Calendar) -> Double? {
        guard let status = data.serviceStatuses(at: date, calendar: calendar).first,
              let interval = status.item.intervalKm, let left = status.kmLeft, interval > 0 else { return nil }
        return min(max(1 - Double(left) / Double(interval), 0), 1)
    }
}

/// Glanceability checks for the builder (spec §4b).
public enum DesignLinter {
    public struct Warning: Sendable, Equatable, Hashable {
        public let message: String
        public let layerID: UUID?
    }

    /// Smallest text that stays readable at a glance on the CarPlay small size (points at 170 pt height).
    public static let minimumFontSize = 14.0
    /// WCAG AA for large text.
    public static let minimumContrast = 3.0

    public static func warnings(for design: CardDesign) -> [Warning] {
        var result: [Warning] = []
        let fields = design.layers.filter { if case .data = $0.content { return true } else { return false } }
        if design.canvas == .small && fields.count > CardDesign.maxSmallDataFields {
            result.append(Warning(message: "Small designs can show at most \(CardDesign.maxSmallDataFields) data fields (this has \(fields.count)).", layerID: nil))
        }
        let background = design.background.approximateHex
        for layer in design.layers where layer.isText {
            if layer.fontSize < minimumFontSize {
                result.append(Warning(message: "Text \(Int(layer.fontSize)) pt is too small to read while driving (use \(Int(minimumFontSize)) pt or more).", layerID: layer.id))
            }
            if let background, layer.opacity > 0.1 {
                let ratio = ColorMath.contrast(layer.colorHex, background)
                if ratio < minimumContrast {
                    result.append(Warning(message: String(format: "Low contrast %.1f:1 against the background (needs %.0f:1).", ratio, minimumContrast), layerID: layer.id))
                }
            }
        }
        return result
    }

    /// True when the design breaks the hard limit (more than 2 data fields on small); saving is blocked.
    public static func blocksSaving(_ design: CardDesign) -> Bool {
        design.canvas == .small && design.layers.filter { if case .data = $0.content { return true } else { return false } }.count > CardDesign.maxSmallDataFields
    }
}
