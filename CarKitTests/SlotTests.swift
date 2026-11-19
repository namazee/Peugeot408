import Foundation
import Testing
@testable import CarKit

@Suite("Slot state")
struct SlotStateTests {
    @Test func starterHasFiveSlots() {
        #expect(SlotsState.starter.slots.count == 5)
        #expect(SlotKind.all == ["CarSlot1", "CarSlot2", "CarSlot3", "CarSlot4", "CarSlot5"])
    }

    @Test func outOfRangeSlotFallsBackToStarter() {
        let state = SlotsState.starter
        #expect(state.design(for: 0) == .starter(for: 0))
        #expect(state.design(for: 9) == .starter(for: 9))
    }

    @Test func normalizePadsAndTrims() {
        let short = SlotsState(slots: [SlotDesign(value: "A", title: "a", symbol: "car.fill")])
        #expect(short.slots.count == 5)
        #expect(short.design(for: 1).value == "A")

        let long = SlotsState(slots: Array(repeating: .starter(for: 1), count: 8))
        #expect(long.slots.count == 5)
    }

    @Test func setDesignChangesOnlyThatSlot() {
        var state = SlotsState.starter
        let custom = SlotDesign(value: "RM 42", title: "TnG", symbol: "creditcard.fill")
        state.setDesign(custom, for: 3)
        #expect(state.design(for: 3) == custom)
        #expect(state.changedSlots(comparedTo: .starter) == [3])
        state.setDesign(custom, for: 7) // ignored
        #expect(state.slots.count == 5)
    }

    @Test func moveMatchesSwiftUISemantics() {
        let designs = ["a", "b", "c", "d", "e"].map { SlotDesign(value: $0, title: $0, symbol: "car.fill") }
        var state = SlotsState(slots: designs)

        state.moveSlots(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(state.slots.map(\.value) == ["b", "c", "a", "d", "e"])

        state.moveSlots(fromOffsets: IndexSet(integer: 4), toOffset: 0)
        #expect(state.slots.map(\.value) == ["e", "b", "c", "a", "d"])

        let before = state
        state.moveSlots(fromOffsets: IndexSet(integer: 1), toOffset: 2) // no-op move
        #expect(state == before)
        #expect(state.changedSlots(comparedTo: before).isEmpty)
    }

    @Test func moveReportsChangedSlots() {
        let designs = ["a", "b", "c", "d", "e"].map { SlotDesign(value: $0, title: $0, symbol: "car.fill") }
        let before = SlotsState(slots: designs)
        var after = before
        after.moveSlots(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(after.changedSlots(comparedTo: before) == [1, 2])
    }
}

@Suite("Slot timeline")
struct SlotTimelineTests {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func noFlashGivesSingleDesignEntry() {
        let items = SlotTimeline.items(slot: 2, state: .starter, now: now)
        #expect(items == [SlotTimelineItem(date: now, content: .design(.starter(for: 2)))])
    }

    @Test func activeFlashShowsFlashThenDesign() {
        var state = SlotsState.starter
        let until = now.addingTimeInterval(600)
        state.flashUntil = until
        let items = SlotTimeline.items(slot: 4, state: state, now: now)
        #expect(items.count == 2)
        #expect(items[0] == SlotTimelineItem(date: now, content: .flash))
        #expect(items[1] == SlotTimelineItem(date: until, content: .design(.starter(for: 4))))
        #expect(state.isFlashing(at: now))
        #expect(!state.isFlashing(at: until))
    }

    @Test func expiredFlashIsIgnored() {
        var state = SlotsState.starter
        state.flashUntil = now.addingTimeInterval(-1)
        let items = SlotTimeline.items(slot: 1, state: state, now: now)
        #expect(items == [SlotTimelineItem(date: now, content: .design(.starter(for: 1)))])
    }
}

@Suite("Slot store")
struct SlotStoreTests {
    private func makeStore() -> SlotStore {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "SlotStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return SlotStore(directory: dir)
    }

    @Test func missingFileLoadsStarter() {
        #expect(makeStore().load() == .starter)
    }

    @Test func roundTrip() throws {
        let store = makeStore()
        var state = SlotsState.starter
        state.setDesign(SlotDesign(value: "Subuh", title: "05:52", symbol: "moon.stars.fill", style: .accent), for: 5)
        state.flashUntil = Date(timeIntervalSinceReferenceDate: 800_000_123.456)
        try store.save(state)
        #expect(store.load() == state)
    }

    @Test func corruptFileLoadsStarter() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: store.fileURL)
        #expect(store.load() == .starter)
    }
}
