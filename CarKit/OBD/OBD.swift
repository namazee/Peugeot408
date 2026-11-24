import Foundation

/// The values read in a drive session (spec §4, item 5).
public enum OBDValue: String, Codable, Sendable, CaseIterable, Identifiable {
    case rpm
    case coolant
    case boost
    case voltage
    case speed
    case intakeAir
    case throttle
    case engineLoad
    case fuelLevel

    public var id: String { rawValue }

    /// The original four, shown by the Live Activity and the Live OBD2 widget (spec §4 item 5).
    public static let core: [OBDValue] = [.rpm, .coolant, .boost, .voltage]

    public var displayName: String {
        switch self {
        case .rpm: "RPM"
        case .coolant: "Coolant"
        case .boost: "Boost"
        case .voltage: "Battery"
        case .speed: "Speed"
        case .intakeAir: "Intake air"
        case .throttle: "Throttle"
        case .engineLoad: "Engine load"
        case .fuelLevel: "Fuel level"
        }
    }

    public var symbol: String {
        switch self {
        case .rpm: "gauge.with.dots.needle.67percent"
        case .coolant: "thermometer.medium"
        case .boost: "tornado"
        case .voltage: "minus.plus.batteryblock.fill"
        case .speed: "speedometer"
        case .intakeAir: "wind"
        case .throttle: "pedal.accelerator.fill"
        case .engineLoad: "engine.combustion.fill"
        case .fuelLevel: "fuelpump.fill"
        }
    }
}

/// ELM327 commands. Mode 01 PIDs per SAE J1979.
public enum OBDCommand: String, Sendable, CaseIterable {
    case rpm = "010C"
    case coolant = "0105"
    case intakePressure = "010B"
    case barometric = "0133"
    case voltage = "ATRV"
    case speed = "010D"
    case intakeAir = "010F"
    case throttle = "0111"
    case engineLoad = "0104"
    case fuelLevel = "012F"

    /// Setup sent once after connecting: reset, echo off, linefeeds off, spaces off,
    /// headers off, automatic protocol.
    public static let initSequence = ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"]

    /// Mode 01 PID 00 (supported PIDs 01–20). Sent once after setup so the adapter finds the
    /// car's protocol before the first real reading.
    public static let supportedPIDs = "0100"
}

/// One poll result.
public struct OBDReading: Codable, Sendable, Equatable {
    public var rpm: Int?
    public var coolantC: Int?
    /// Intake manifold pressure minus barometric pressure, in bar (negative = vacuum).
    public var boostBar: Double?
    public var voltage: Double?
    /// km/h. Nil in older files (like the other extra values below).
    public var speedKmh: Int?
    public var intakeAirC: Int?
    /// 0–100 %.
    public var throttlePercent: Int?
    public var engineLoadPercent: Int?
    public var fuelLevelPercent: Int?
    public var date: Date

    public init(rpm: Int? = nil, coolantC: Int? = nil, boostBar: Double? = nil, voltage: Double? = nil,
                speedKmh: Int? = nil, intakeAirC: Int? = nil, throttlePercent: Int? = nil, engineLoadPercent: Int? = nil,
                fuelLevelPercent: Int? = nil, date: Date) {
        self.rpm = rpm
        self.coolantC = coolantC
        self.boostBar = boostBar
        self.voltage = voltage
        self.speedKmh = speedKmh
        self.intakeAirC = intakeAirC
        self.throttlePercent = throttlePercent
        self.engineLoadPercent = engineLoadPercent
        self.fuelLevelPercent = fuelLevelPercent
        self.date = date
    }

    public func text(_ value: OBDValue) -> String {
        switch value {
        case .rpm: rpm.map { $0.formatted() } ?? "--"
        case .coolant: coolantC.map { "\($0)°C" } ?? "--"
        case .boost: boostBar.map { String(format: "%+.2f bar", $0) } ?? "--"
        case .voltage: voltage.map { String(format: "%.1f V", $0) } ?? "--"
        case .speed: speedKmh.map { "\($0) km/h" } ?? "--"
        case .intakeAir: intakeAirC.map { "\($0)°C" } ?? "--"
        case .throttle: throttlePercent.map { "\($0)%" } ?? "--"
        case .engineLoad: engineLoadPercent.map { "\($0)%" } ?? "--"
        case .fuelLevel: fuelLevelPercent.map { "\($0)%" } ?? "--"
        }
    }

    /// The number alone, its unit and a 0…1 position for a gauge (Split/Quad cards, spec §4b).
    public func gauge(_ value: OBDValue) -> (number: String?, unit: String, progress: Double?) {
        switch value {
        case .boost: (boostBar.map { String(format: "%+.2f", $0) }, "bar", boostBar.map { ($0 + 1) / 2.5 })
        case .rpm: (rpm.map { $0.formatted() }, "rpm", rpm.map { Double($0) / 7_000 })
        case .coolant: (coolantC.map(String.init), "°C", coolantC.map { Double($0 - 40) / 80 })
        case .voltage: (voltage.map { String(format: "%.1f", $0) }, "V", voltage.map { ($0 - 11) / 4 })
        case .speed: (speedKmh.map(String.init), "km/h", speedKmh.map { Double($0) / 200 })
        case .intakeAir: (intakeAirC.map(String.init), "°C", intakeAirC.map { Double($0) / 80 })
        case .throttle: (throttlePercent.map(String.init), "%", throttlePercent.map { Double($0) / 100 })
        case .engineLoad: (engineLoadPercent.map(String.init), "%", engineLoadPercent.map { Double($0) / 100 })
        case .fuelLevel: (fuelLevelPercent.map(String.init), "%", fuelLevelPercent.map { Double($0) / 100 })
        }
    }
}

public enum OBDParseError: Error, Equatable, Sendable {
    /// The car didn't answer this PID (`NO DATA`) or the adapter didn't know the command (`?`).
    case unsupported
    /// `UNABLE TO CONNECT`, `CAN ERROR`, `BUS INIT…ERROR`: ignition off or no protocol.
    case noConnection
    case unreadable
}

/// Parses ELM327 replies. Works with spaces on or off, echo on or off, and extra lines
/// such as `SEARCHING...`; with several ECUs answering it takes the first answer.
public enum OBDParser {
    /// Data bytes A, B, … after `41 <pid>` for a mode-01 request.
    public static func dataBytes(for pid: String, in response: String) throws -> [UInt8] {
        let upper = response.uppercased()
        if upper.contains("UNABLE TO CONNECT") || upper.contains("CAN ERROR") || upper.contains("BUS INIT") || upper.contains("BUS ERROR") {
            throw OBDParseError.noConnection
        }
        if upper.contains("NO DATA") || upper.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("?") {
            throw OBDParseError.unsupported
        }
        let pidCode = String(pid.uppercased().suffix(2))
        let marker = "41" + pidCode
        for line in upper.split(whereSeparator: { $0 == "\r" || $0 == "\n" || $0 == ">" }) {
            let hex = line.filter(\.isHexDigit)
            // Skip the echoed request ("010C") and status lines.
            guard let range = hex.range(of: marker) else { continue }
            let payload = hex[range.upperBound...]
            var bytes: [UInt8] = []
            var index = payload.startIndex
            while let next = payload.index(index, offsetBy: 2, limitedBy: payload.endIndex), index < payload.endIndex {
                guard let byte = UInt8(payload[index..<next], radix: 16) else { break }
                bytes.append(byte)
                index = next
            }
            if !bytes.isEmpty { return bytes }
        }
        throw OBDParseError.unreadable
    }

    /// `ATRV` reply, e.g. "12.6V" or "14.2V\r\r>".
    public static func voltage(_ response: String) throws -> Double {
        let cleaned = response.uppercased().filter { $0.isNumber || $0 == "." }
        guard let value = Double(cleaned), (5...20).contains(value) else { throw OBDParseError.unreadable }
        return value
    }

    // MARK: Formulas

    /// PID 0C: ((A × 256) + B) / 4.
    public static func rpm(_ bytes: [UInt8]) throws -> Int {
        guard bytes.count >= 2 else { throw OBDParseError.unreadable }
        return (Int(bytes[0]) * 256 + Int(bytes[1])) / 4
    }

    /// PID 05: A − 40 °C.
    public static func coolant(_ bytes: [UInt8]) throws -> Int {
        guard let a = bytes.first else { throw OBDParseError.unreadable }
        return Int(a) - 40
    }

    /// PID 0B / 33: A kPa (absolute).
    public static func kilopascals(_ bytes: [UInt8]) throws -> Int {
        guard let a = bytes.first else { throw OBDParseError.unreadable }
        return Int(a)
    }

    /// Boost in bar: manifold absolute pressure minus barometric pressure (1 bar = 100 kPa).
    public static func boostBar(manifoldKPa: Int, barometricKPa: Int) -> Double {
        Double(manifoldKPa - barometricKPa) / 100
    }

    /// Sea-level barometric pressure, used until PID 33 has been read (or when the car doesn't report it).
    public static let standardBarometricKPa = 101

    /// PID 0D: A km/h.
    public static func speed(_ bytes: [UInt8]) throws -> Int {
        guard let a = bytes.first else { throw OBDParseError.unreadable }
        return Int(a)
    }

    /// PID 0F: A − 40 °C (same as coolant).
    public static func intakeAir(_ bytes: [UInt8]) throws -> Int {
        try coolant(bytes)
    }

    /// PIDs 04, 11, 2F: A × 100 / 255 %, rounded.
    public static func percent(_ bytes: [UInt8]) throws -> Int {
        guard let a = bytes.first else { throw OBDParseError.unreadable }
        return Int((Double(a) * 100 / 255).rounded())
    }
}

/// Simulated values for testing without a dongle: idle, then a rev every 20 seconds.
public enum OBDDemo {
    public static func reading(at date: Date, sessionStart: Date) -> OBDReading {
        let t = date.timeIntervalSince(sessionStart)
        let cycle = t.truncatingRemainder(dividingBy: 20)
        // 0–12 s cruise ~2,000 rpm, 12–15 s pull to ~5,500, then back off.
        let rpm: Double
        let boost: Double
        switch cycle {
        case ..<12:
            rpm = 1_900 + 150 * sin(t / 2)
            boost = -0.35 + 0.05 * sin(t)
        case ..<15:
            let x = (cycle - 12) / 3
            rpm = 2_000 + 3_500 * x
            boost = -0.2 + 1.35 * min(x * 1.6, 1)
        default:
            let x = (cycle - 15) / 5
            rpm = 5_500 - 3_600 * x
            boost = 1.15 - 1.5 * min(x * 2, 1)
        }
        // Coolant warms from 40 °C to 90 °C over the first 8 minutes.
        let coolant = 40 + min(t / 480, 1) * 50
        let voltage = 14.1 + 0.15 * sin(t / 7)
        // Throttle and load follow the rev; speed follows rpm in one gear; fuel drains slowly.
        let effort = min(max((rpm - 1_750) / 3_750, 0), 1)
        return OBDReading(
            rpm: Int(rpm.rounded()),
            coolantC: Int(coolant.rounded()),
            boostBar: (boost * 100).rounded() / 100,
            voltage: (voltage * 10).rounded() / 10,
            speedKmh: Int((rpm / 30).rounded()),
            intakeAirC: Int((38 + 4 * sin(t / 30)).rounded()),
            throttlePercent: Int((12 + 80 * effort).rounded()),
            engineLoadPercent: Int((22 + 70 * effort).rounded()),
            fuelLevelPercent: max(62 - Int(t / 300), 0),
            date: date
        )
    }
}

/// BLE service/characteristic UUIDs. ELM327 BLE adapters don't share one standard, so these are
/// configurable, with presets for common adapters (spec: "make the UUIDs configurable").
public struct OBDAdapterProfile: Codable, Sendable, Equatable, Hashable {
    public var name: String
    public var serviceUUID: String
    public var notifyUUID: String
    public var writeUUID: String

    public init(name: String, serviceUUID: String, notifyUUID: String, writeUUID: String) {
        self.name = name
        self.serviceUUID = serviceUUID
        self.notifyUUID = notifyUUID
        self.writeUUID = writeUUID
    }

    /// Most ELM327 BLE adapters, including OBDLink CX: service FFF0, notify FFF1, write FFF2.
    public static let fff0 = OBDAdapterProfile(name: "Generic BLE (FFF0)", serviceUUID: "FFF0", notifyUUID: "FFF1", writeUUID: "FFF2")
    /// Vgate iCar Pro BLE and similar: one characteristic for notify and write.
    public static let vgate = OBDAdapterProfile(
        name: "Vgate iCar Pro BLE",
        serviceUUID: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2",
        notifyUUID: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F",
        writeUUID: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F"
    )
    public static let presets: [OBDAdapterProfile] = [.fff0, .vgate]

    public var isValid: Bool {
        [serviceUUID, notifyUUID, writeUUID].allSatisfy(Self.isValidUUID)
    }

    /// 16-bit ("FFF0") or full 128-bit UUID.
    public static func isValidUUID(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespaces).uppercased()
        if value.count == 4 { return value.allSatisfy(\.isHexDigit) }
        return UUID(uuidString: value) != nil
    }
}

/// `obd.json`: dongle settings and the last values, for the OBD2 widget.
public struct OBDState: Codable, Sendable, Equatable {
    public var profile: OBDAdapterProfile
    /// Remembered dongle (CoreBluetooth peripheral identifier).
    public var peripheralID: UUID?
    public var peripheralName: String?
    /// Seconds between full polls (all PIDs).
    public var pollInterval: Double
    public var last: OBDReading?
    public var lastWasDemo: Bool
    /// PIDs the car didn't answer in the last live session.
    public var unsupported: Set<OBDValue>
    public var sessionActive: Bool

    public init(profile: OBDAdapterProfile = .fff0, peripheralID: UUID? = nil, peripheralName: String? = nil, pollInterval: Double = 1.5, last: OBDReading? = nil, lastWasDemo: Bool = false, unsupported: Set<OBDValue> = [], sessionActive: Bool = false) {
        self.profile = profile
        self.peripheralID = peripheralID
        self.peripheralName = peripheralName
        self.pollInterval = pollInterval
        self.last = last
        self.lastWasDemo = lastWasDemo
        self.unsupported = unsupported
        self.sessionActive = sessionActive
    }

    public static let empty = OBDState()
}

public enum OBDStores {
    public static func state(in directory: URL = AppGroup.containerURL) -> JSONFileStore<OBDState> {
        JSONFileStore(directory: directory, fileName: "obd.json") { .empty }
    }
}

public struct OBDSummary: Sendable, Equatable {
    public let reading: OBDReading?
    public let isDemo: Bool
    public let sessionActive: Bool
    public let unsupported: Set<OBDValue>
    /// The value a Split/Quad card shows big (spec §4b "Value" picker). Boost unless chosen.
    public var focus: OBDValue

    public init(reading: OBDReading?, isDemo: Bool, sessionActive: Bool, unsupported: Set<OBDValue>, focus: OBDValue = .boost) {
        self.reading = reading
        self.isDemo = isDemo
        self.sessionActive = sessionActive
        self.unsupported = unsupported
        self.focus = focus
    }

    public func focused(on value: OBDValue) -> OBDSummary {
        var copy = self
        copy.focus = value
        return copy
    }

    /// Icon for the focused value (Boost keeps the gauge it always had).
    public var focusSymbol: String {
        focus == .boost ? "gauge.with.dots.needle.67percent" : focus.symbol
    }

    /// Amber when hot or the battery is low.
    public var urgency: Urgency {
        guard let reading else { return .ok }
        if let c = reading.coolantC, c >= 110 { return .urgent }
        if let v = reading.voltage, v < 11.8 { return .urgent }
        if let c = reading.coolantC, c >= 105 { return .dueSoon }
        if let v = reading.voltage, v < 12.2 { return .dueSoon }
        return .ok
    }
}
