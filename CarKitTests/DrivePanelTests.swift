import Foundation
import Testing
@testable import CarKit

/// Phase 20 (spec §4 item 5): the four values on the Drive session panel.
struct DrivePanelTests {
    @Test func defaultsToTheOriginalFour() {
        #expect(OBDState().panel == [.boost, .rpm, .coolant, .voltage])
        #expect(OBDPanel.normalized(nil) == OBDPanel.defaultValues)
    }

    @Test func alwaysFourDifferentValues() {
        #expect(OBDPanel.normalized([.speed]) == [.speed, .boost, .rpm, .coolant])
        #expect(OBDPanel.normalized([.fuelLevel, .fuelLevel, .speed]) == [.fuelLevel, .speed, .boost, .rpm])
        let tooMany = OBDPanel.normalized(OBDValue.allCases)
        #expect(tooMany.count == 4)
        #expect(Set(tooMany).count == 4)
    }

    @Test func pickingAValueAlreadyThereSwaps() {
        let start: [OBDValue] = [.boost, .rpm, .coolant, .voltage]
        #expect(OBDPanel.setting(.speed, at: 0, in: start) == [.speed, .rpm, .coolant, .voltage])
        #expect(OBDPanel.setting(.voltage, at: 0, in: start) == [.voltage, .rpm, .coolant, .boost])
        #expect(OBDPanel.setting(.speed, at: 9, in: start) == start)
    }

    @Test func olderObdFilesStillLoad() throws {
        let data = try JSONEncoder().encode(OBDState(pollInterval: 2))
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "panelValues")
        let back = try JSONDecoder().decode(OBDState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(back.panel == OBDPanel.defaultValues)
        #expect(back.pollInterval == 2)
    }

    @Test func liveActivityCarriesEveryValueAndThePanel() throws {
        let reading = OBDDemo.reading(at: .now.addingTimeInterval(20), sessionStart: .now)
        let state = DriveActivityAttributes.ContentState(reading: reading, status: "Live", panel: [.speed, .fuelLevel])
        let back = try JSONDecoder().decode(DriveActivityAttributes.ContentState.self, from: JSONEncoder().encode(state))
        #expect(back.panel == [.speed, .fuelLevel, .boost, .rpm])
        #expect(back.reading.speedKmh == reading.speedKmh)
        #expect(back.reading.fuelLevelPercent == reading.fuelLevelPercent)
    }
}
