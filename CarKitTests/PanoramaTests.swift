import Foundation
import Testing
@testable import CarKit

@Suite("Panorama hero")
struct PanoramaTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt
        return calendar
    }

    @Test func geometryCutsThreeColumnsWithGaps() {
        #expect(PanoramaGeometry.partStart(0) == 0)
        let end = PanoramaGeometry.partStart(2) + PanoramaGeometry.partWidth
        #expect(abs(end - 1) < 1e-9)
        #expect(PanoramaGeometry.partStart(1) > PanoramaGeometry.partWidth)   // a gap before part 2
        #expect(abs(DesignCanvas.panorama.aspectRatio - 3.12 * 0.72) < 1e-9)
    }

    @Test func slotsOneToThreeShowTheirPartAndKeepTheirDesigns() {
        let hero = Templates.make(.hero)
        #expect(hero.canvas == .panorama)
        var studio = StudioState(designs: [hero])
        studio.ownerName = "Namazee"
        var state = SlotsState.starter
        let slotOne = state.design(for: 1)
        state.panorama = PanoramaSettings(enabled: true, designID: hero.id)
        let now = Date()
        for slot in 1...3 {
            guard case .panorama(let card, let part, _) = SlotTimeline.items(slot: slot, state: state, studio: studio, now: now).first?.content else {
                Issue.record("slot \(slot) should show the panorama")
                continue
            }
            #expect(part == slot - 1)
            #expect(card.design.id == hero.id)
        }
        if case .panorama = SlotTimeline.items(slot: 4, state: state, studio: studio, now: now).first?.content {
            Issue.record("slot 4 isn't part of the panorama")
        }
        #expect(SlotTimeline.sources(slot: 2, state: state, studio: studio).contains(.weather))
        #expect(SlotTimeline.needsData(slot: 3, state: state, studio: studio))
        #expect(state.design(for: 1) == slotOne)
        state.panorama?.enabled = false
        if case .panorama = SlotTimeline.items(slot: 1, state: state, studio: studio, now: now).first?.content {
            Issue.record("turned off: slot 1 shows its own design again")
        }
    }

    @Test func greetingFollowsTheTimeOfDay() {
        func at(_ hour: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: hour)) ?? .now }
        #expect(DesignResolver.greetingText(at: at(8), name: "Namazee", malay: false, calendar: calendar) == "Good morning, Namazee")
        #expect(DesignResolver.greetingText(at: at(13), name: "", malay: true, calendar: calendar) == "Selamat tengah hari")
        #expect(DesignResolver.greetingText(at: at(21), name: nil, malay: false, calendar: calendar) == "Good evening")
        let hero = Templates.make(.hero)
        let dates = DesignResolver.dates(for: hero, data: .empty, from: at(9), calendar: calendar)
        #expect(dates.contains(at(12)))   // the greeting changes at noon
    }

    @Test func olderSlotFilesHaveNoPanorama() throws {
        let json = #"{"version":2,"slots":[]}"#
        let state = try JSONDecoder().decode(SlotsState.self, from: Data(json.utf8))
        #expect(state.panorama == nil && state.activePanoramaID == nil)
    }
}
