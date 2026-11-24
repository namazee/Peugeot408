import Foundation
import Testing
@testable import CarKit

@Suite("OBD2")
struct OBDTests {
    @Test func parsesRPMWithSpacesOff() throws {
        let bytes = try OBDParser.dataBytes(for: "010C", in: "410C1AF8\r\r>")
        #expect(bytes == [0x1A, 0xF8])
        #expect(try OBDParser.rpm(bytes) == 1_726)  // (26 × 256 + 248) / 4
    }

    @Test func parsesWithSpacesEchoAndSearching() throws {
        let reply = "010C\rSEARCHING...\r41 0C 0F A0 \r\r>"
        #expect(try OBDParser.rpm(OBDParser.dataBytes(for: "010C", in: reply)) == 1_000)
    }

    @Test func firstECUWinsWhenSeveralAnswer() throws {
        let reply = "41 05 7B\r41 05 50\r>"
        #expect(try OBDParser.coolant(OBDParser.dataBytes(for: "0105", in: reply)) == 83) // 0x7B − 40
    }

    @Test func noDataMeansUnsupported() {
        #expect(throws: OBDParseError.unsupported) { try OBDParser.dataBytes(for: "010B", in: "NO DATA\r\r>") }
        #expect(throws: OBDParseError.unsupported) { try OBDParser.dataBytes(for: "010B", in: "?\r>") }
        #expect(throws: OBDParseError.noConnection) { try OBDParser.dataBytes(for: "010C", in: "SEARCHING...\rUNABLE TO CONNECT\r>") }
        #expect(throws: OBDParseError.unreadable) { try OBDParser.dataBytes(for: "010C", in: "OK\r>") }
    }

    @Test func coolantFormula() throws {
        #expect(try OBDParser.coolant([0x28]) == 0)      // 40 − 40
        #expect(try OBDParser.coolant([0x82]) == 90)     // 130 − 40
    }

    @Test func boostIsManifoldMinusBarometricInBar() {
        #expect(OBDParser.boostBar(manifoldKPa: 180, barometricKPa: 100) == 0.8)
        #expect(OBDParser.boostBar(manifoldKPa: 35, barometricKPa: 100) == -0.65)  // vacuum at idle
        #expect(OBDParser.boostBar(manifoldKPa: 101, barometricKPa: 101) == 0)
    }

    @Test func boostFromRawReplies() throws {
        let map = try OBDParser.kilopascals(OBDParser.dataBytes(for: "010B", in: "410BB4\r>"))   // 180 kPa
        let baro = try OBDParser.kilopascals(OBDParser.dataBytes(for: "0133", in: "413364\r>"))  // 100 kPa
        #expect(OBDParser.boostBar(manifoldKPa: map, barometricKPa: baro) == 0.8)
    }

    @Test func batteryVoltage() throws {
        #expect(try OBDParser.voltage("12.6V\r\r>") == 12.6)
        #expect(try OBDParser.voltage("ATRV\r14.2V>") == 14.2)
        #expect(throws: OBDParseError.unreadable) { try OBDParser.voltage("?") }
    }

    @Test func demoValuesStayPlausible() {
        let start = Date(timeIntervalSince1970: 0)
        for second in stride(from: 0, through: 600, by: 3) {
            let reading = OBDDemo.reading(at: start.addingTimeInterval(Double(second)), sessionStart: start)
            #expect((700...6_500).contains(reading.rpm ?? 0))
            #expect((-1.0...1.5).contains(reading.boostBar ?? 9))
            #expect((40...90).contains(reading.coolantC ?? 0))
            #expect((13.5...14.5).contains(reading.voltage ?? 0))
        }
        // The pull at 12–15 s reaches positive boost.
        #expect((OBDDemo.reading(at: start.addingTimeInterval(14.5), sessionStart: start).boostBar ?? 0) > 0.8)
    }

    @Test func adapterUUIDValidation() {
        #expect(OBDAdapterProfile.fff0.isValid)
        #expect(OBDAdapterProfile.vgate.isValid)
        #expect(!OBDAdapterProfile(name: "x", serviceUUID: "FFG0", notifyUUID: "FFF1", writeUUID: "FFF2").isValid)
    }

    @Test func cardWarnsWhenHotOrBatteryLow() {
        let hot = OBDSummary(reading: OBDReading(coolantC: 112, voltage: 14, date: .now), isDemo: false, sessionActive: false, unsupported: [])
        #expect(hot.urgency == .urgent)
        let lowBattery = OBDSummary(reading: OBDReading(coolantC: 90, voltage: 12.0, date: .now), isDemo: false, sessionActive: false, unsupported: [])
        #expect(lowBattery.urgency == .dueSoon)
        let data = CarData(obd: OBDState(last: OBDReading(coolantC: 112, date: .now)))
        #expect(data.card(for: .obd, at: .now).urgency == .urgent)
    }

    @Test func readingText() {
        let reading = OBDReading(rpm: 2_150, coolantC: 88, boostBar: 0.75, voltage: 14.1, date: .now)
        #expect(reading.text(.boost) == "+0.75 bar")
        #expect(reading.text(.coolant) == "88°C")
        #expect(reading.text(.voltage) == "14.1 V")
        #expect(OBDReading(date: .now).text(.rpm) == "--")
    }

    /// Spec §4b: two Live OBD2 cards in one slot can show different values; no choice = Boost.
    @Test func splitCardsShowTheirChosenValue() {
        let data = CarData(obd: OBDState(last: OBDReading(rpm: 2_150, coolantC: 88, boostBar: 0.75, voltage: 14.1, date: .now)))
        var top = SlotDesign.card(.obd)
        top.obdValue = .rpm
        var design = SlotDesign.starter(for: 2)
        design.layout = .split
        design.cards = [top, .card(.obd)]
        let content = SlotTimeline.content(at: .now, design: design, rotations: [], seasonal: false, data: data, studio: .empty)
        guard case .cards(_, let parts) = content,
              case .data(let first) = parts[0], case .data(let second) = parts[1] else {
            Issue.record("expected two data cards"); return
        }
        #expect(first.compact.label == "RPM")
        #expect(first.compact.value == .text("2,150") || first.compact.value == .text("2150"))
        #expect(second.compact.label == "Boost")
        #expect(second.compact.value == .text("+0.75 bar"))
        #expect(first.face?.unit == "rpm")
    }
}
