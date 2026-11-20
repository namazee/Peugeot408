import Foundation

/// The values read in a drive session (spec §4, item 5).
public enum OBDValue: String, Codable, Sendable, CaseIterable, Identifiable {
    case rpm
    case coolant
    case boost
    case voltage

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .rpm: "RPM"
        case .coolant: "Coolant"
        case .boost: "Boost"
        case .voltage: "Battery"
        }
    }

    public var symbol: String {
        switch self {
        case .rpm: "gauge.with.dots.needle.67percent"
        case .coolant: "thermometer.medium"
        case .boost: "tornado"
        case .voltage: "minus.plus.batteryblock.fill"
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

    /// Setup sent once after connecting: reset, echo off, linefeeds off, spaces off,
    /// headers off, automatic protocol.
    public static let initSequence = ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"]
}

/// One poll result.
public struct OBDReading: Codable, Sendable, Equatable {
    public var rpm: Int?
    public var coolantC: Int?
    /// Intake manifold pressure minus barometric pressure, in bar (negative = vacuum).
    public var boostBar: Double?
    public var voltage: Double?
    public var date: Date

    public init(rpm: Int? = nil, coolantC: Int? = nil, boostBar: Double? = nil, voltage: Double? = nil, date: Date) {
        self.rpm = rpm
        self.coolantC = coolantC
        self.boostBar = boostBar
        self.voltage = voltage
        self.date = date
    }

    public func text(_ value: OBDValue) -> String {
        switch value {
        case .rpm: rpm.map { $0.formatted() } ?? "--"
        case .coolant: coolantC.map { "\($0)°C" } ?? "--"
        case .boost: boostBar.map { String(format: "%+.2f bar", $0) } ?? "--"
        case .voltage: voltage.map { String(format: "%.1f V", $0) } ?? "--"
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
        return OBDReading(
            rpm: Int(rpm.rounded()),
            coolantC: Int(coolant.rounded()),
            boostBar: (boost * 100).rounded() / 100,
            voltage: (voltage * 10).rounded() / 10,
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

    public init(reading: OBDReading?, isDemo: Bool, sessionActive: Bool, unsupported: Set<OBDValue>) {
        self.reading = reading
        self.isDemo = isDemo
        self.sessionActive = sessionActive
        self.unsupported = unsupported
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
