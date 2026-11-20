import Foundation
import Testing
@testable import CarKit

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt
    return calendar
}()

private let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9)) ?? .now

@Suite("Split-card slot layouts")
struct SplitLayoutTests {
    @Test func defaultSetupMatchesTheSpec() {
        let state = SlotsState.starter
        let expected: [Int: [DataSource]] = [1: [.prayer, .renewals], 2: [.service, .fuel], 3: [.weather, .parking]]
        for (slot, sources) in expected {
            let design = state.design(for: slot)
            #expect(design.effectiveLayout == .split)
            #expect(design.layoutCards.map(\.source) == sources)
        }
        // Slots 4 and 5 stay single, for stacking behind the columns.
        #expect(state.design(for: 4).effectiveLayout == .single)
        #expect(state.design(for: 5).effectiveLayout == .single)
    }

    @Test func olderFilesMoveToTheDefaultSetupOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SlotStore(directory: directory)
        var old = SlotsState(version: 1, slots: SlotsState.slotNumbers.map(SlotDesign.starter(for:)))
        old.setDesign(SlotDesign(value: "Mine", title: "kept", symbol: "star.fill"), for: 5)
        try store.save(old)
        let loaded = store.load()
        #expect(loaded.version == 2)
        #expect(loaded.design(for: 1).layoutCards.map(\.source) == [.prayer, .renewals])
        #expect(loaded.design(for: 5).value == "Mine")
        // Once saved at version 2, my own changes to slots 1–3 are kept.
        var mine = loaded
        mine.setDesign(.card(.tng), for: 1)
        try store.save(mine)
        #expect(store.load().design(for: 1).source == .tng)
    }

    @Test func splitShowsTwoCardsQuadFour() {
        let data = CarData(tng: TnGState(balance: 42))
        var state = SlotsState.starter
        var design = SlotDesign.starter(for: 2)
        design.setLayout(.quad)
        state.setDesign(design, for: 2)
        guard case .cards(let layout, let parts) = SlotTimeline.items(slot: 2, state: state, data: data, now: now, calendar: calendar).first?.content else {
            Issue.record("expected cards")
            return
        }
        #expect(layout == .quad)
        #expect(parts.count == 4)
        guard case .cards(.split, let split) = SlotTimeline.items(slot: 1, state: .starter, data: data, now: now, calendar: calendar).first?.content else {
            Issue.record("expected split cards")
            return
        }
        #expect(split.count == 2)
    }

    @Test func switchingLayoutKeepsCards() {
        var design = SlotDesign.splitDefault(for: 2) ?? .starter(for: 2)
        design.setLayout(.quad)
        #expect(design.layoutCards.prefix(2).map(\.source) == [.service, .fuel])
        #expect(design.layoutCards.count == 4)
        design.setLayout(.split)
        #expect(design.layoutCards.map(\.source) == [.service, .fuel])
    }

    @Test func singleDataSlotBecomesFirstCard() {
        var design = SlotDesign.card(.tng)
        design.setLayout(.split)
        #expect(design.layoutCards.first?.source == .tng)
    }

    @Test func entryDatesCoverEveryCard() {
        // Prayer card needs entries at prayer times; the road-tax card at midnights.
        let zone = PrayerZone.zone(code: "SGR01") ?? PrayerZone.all[0]
        let days = (0...2).compactMap { offset -> PrayerDay? in
            calendar.date(byAdding: .day, value: offset, to: now).flatMap { PrayerCalculator.jakim.day(for: $0, zone: zone) }
        }
        let data = CarData(prayer: PrayerCache(zoneCode: "SGR01", days: days))
        let items = SlotTimeline.items(slot: 1, state: .starter, data: data, now: now, calendar: calendar)
        let dates = Set(items.map(\.date))
        #expect(dates.isSuperset(of: DataTimeline.dates(for: .prayer, data: data, from: now, calendar: calendar)))
        #expect(dates.isSuperset(of: DataTimeline.dates(for: .renewals, data: data, from: now, calendar: calendar)))
    }

    @Test func flashLabelsEachCard() {
        #expect(SlotTimeline.flashContent(for: SlotsState.starter.design(for: 2)) == .cards(.split, [.flashCard("Top"), .flashCard("Bottom")]))
        #expect(SlotTimeline.flashContent(for: SlotsState.starter.design(for: 4)) == .flash)
        var state = SlotsState.starter
        state.flashUntil = now.addingTimeInterval(600)
        let first = SlotTimeline.items(slot: 3, state: state, now: now, calendar: calendar).first?.content
        #expect(first == .cards(.split, [.flashCard("Top"), .flashCard("Bottom")]))
    }

    @Test func sourcesIncludeEveryCard() {
        #expect(SlotTimeline.sources(slot: 3, state: .starter, studio: .empty) == [.weather, .parking])
        #expect(SlotTimeline.needsData(slot: 3, state: .starter, studio: .empty))
        #expect(!SlotTimeline.needsData(slot: 4, state: .starter, studio: .empty))
    }

    @Test func compactCardsCarryUrgency() {
        let low = DataCard.tng(TnGSummary(balance: 8, threshold: 20, isLow: true)).compact
        #expect(low.urgency == .dueSoon)
        #expect(low.value == .text("RM 8.00"))
        let prayer = CarData.empty.card(for: .prayer, at: now).compact
        #expect(prayer.value == .text("--"))
    }

    @Test func summaryNamesBothCards() {
        #expect(SlotsState.starter.design(for: 2).summary == "Service Tracker / Fuel Log")
    }
}
