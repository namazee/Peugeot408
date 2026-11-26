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

    /// Turns the Panorama hero on or off (Slots 1–3 keep their own designs underneath).
    func setPanorama(_ settings: PanoramaSettings?) {
        var next = state
        var settings = settings
        // Callers that only switch the panorama or its design keep the Blend edges choice.
        if settings != nil, settings?.blendEdges == nil { settings?.blendEdges = state.panorama?.blendEdges }
        next.panorama = settings
        commit(next, reloadingSlots: Array(1...PanoramaGeometry.columns))
    }

    /// Spec §4b (Phase 19): fills all five slots with a ready-made setup; "Undo setup" brings them back.
    func apply(_ setup: ReadySetup, designs: [CardDesign]) {
        var next = state
        next.apply(setup, designs: designs)
        commit(next, reloading: SlotsState.slotNumbers)
    }

    func undoSetup() {
        var next = state
        guard next.undoLastSetup() else { return }
        commit(next, reloading: SlotsState.slotNumbers)
    }

    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func commit(_ next: SlotsState, reloadingSlots slots: [Int]) {
        commit(next, reloading: slots)
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
