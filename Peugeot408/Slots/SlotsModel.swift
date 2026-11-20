import CarKit
import Foundation
import Observation
import WidgetKit

/// App-side owner of the slot assignments. Every change is saved to the App Group
/// and only the affected slot widgets are reloaded.
@MainActor
@Observable
final class SlotsModel {
    private(set) var state: SlotsState
    var lastError: String?

    @ObservationIgnored private let store: SlotStore

    /// How long "Test: flash all slots" keeps the identifying cards up.
    static let flashDuration: TimeInterval = 10 * 60

    init(store: SlotStore = .live) {
        self.store = store
        self.state = store.load()
    }

    func design(for slot: Int) -> SlotDesign {
        state.design(for: slot)
    }

    func save(_ design: SlotDesign, for slot: Int) {
        var next = state
        next.setDesign(design, for: slot)
        commit(next, reloading: [slot])
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var next = state
        next.moveSlots(fromOffsets: source, toOffset: destination)
        commit(next, reloading: next.changedSlots(comparedTo: state))
    }

    func flashAll() {
        var next = state
        next.flashUntil = Date().addingTimeInterval(Self.flashDuration)
        commit(next, reloading: SlotsState.slotNumbers)
    }

    func stopFlash() {
        var next = state
        next.flashUntil = nil
        commit(next, reloading: SlotsState.slotNumbers)
    }

    /// Re-reads the file (after a backup is restored).
    func reload() {
        state = store.load()
    }

    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func commit(_ next: SlotsState, reloading slots: [Int]) {
        do {
            try store.save(next)
            state = next
            lastError = nil
            for slot in slots {
                WidgetCenter.shared.reloadTimelines(ofKind: SlotKind.kind(for: slot))
            }
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
