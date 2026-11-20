import CarKit
import Foundation
import Observation
import WidgetKit

/// App-side owner of `studio.json` (designs, seasonal packs, My Car photo).
/// Saving reloads only the Car Slots that can show the changed design.
@MainActor
@Observable
final class StudioModel {
    private(set) var state: StudioState
    var lastError: String?

    @ObservationIgnored let directory: URL

    init(directory: URL = AppGroup.containerURL) {
        self.directory = directory
        self.state = StudioStores.studio(in: directory).load()
    }

    func reload() {
        state = StudioStores.studio(in: directory).load()
    }

    func design(_ id: UUID?) -> CardDesign? { state.design(id) }

    func save(_ design: CardDesign) {
        var next = state
        var stamped = design
        stamped.updatedAt = .now
        if let index = next.designs.firstIndex(where: { $0.id == design.id }) {
            next.designs[index] = stamped
        } else {
            next.designs.append(stamped)
        }
        commit(next, reloadSlotsShowing: [design.id])
    }

    func delete(_ ids: Set<UUID>) {
        var next = state
        next.designs.removeAll { ids.contains($0.id) }
        commit(next, reloadSlotsShowing: ids)
    }

    func updateSeasonal(_ change: (inout SeasonalSettings) -> Void) {
        var next = state
        let oldSlot = next.seasonal.slot
        change(&next.seasonal)
        commit(next, reloadSlotsShowing: [])
        reloadSlots([oldSlot, next.seasonal.slot])
    }

    func setCarPhoto(file: String?, plate: String? = nil) {
        var next = state
        next.carPhotoFile = file
        if let plate { next.plateText = plate }
        commit(next, reloadSlotsShowing: Set(next.designs.filter { $0.layers.contains { $0.content == .carPhoto || $0.content == .plate("") } }.map(\.id)))
    }

    func setPlate(_ text: String) {
        var next = state
        next.plateText = text
        commit(next, reloadSlotsShowing: Set(next.designs.map(\.id)))
    }

    /// Imports a design file (fresh id).
    func importDesign(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let design = try CardDesign.importing(Data(contentsOf: url))
            save(design)
        } catch {
            lastError = "Couldn't import: \(error.localizedDescription)"
        }
    }

    /// A file for the share sheet.
    func exportURL(for design: CardDesign) -> URL? {
        let safe = design.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(safe).peugeot408.json", directoryHint: .notDirectory)
        do {
            try design.exportData().write(to: url, options: .atomic)
            return url
        } catch {
            lastError = "Couldn't export: \(error.localizedDescription)"
            return nil
        }
    }

    private func commit(_ next: StudioState, reloadSlotsShowing ids: Set<UUID>) {
        do {
            try StudioStores.studio(in: directory).save(next)
            state = next
            lastError = nil
        } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
            return
        }
        let slots = SlotStore(directory: directory).load()
        let affected = SlotsState.slotNumbers.filter { slot in
            let design = slots.design(for: slot)
            let choices = [design.primaryChoice] + (design.rotations ?? []).map(\.choice)
            return choices.contains { $0.studioDesignID.map(ids.contains) ?? false }
        }
        reloadSlots(affected)
    }

    private func reloadSlots(_ slots: [Int]) {
        for slot in Set(slots) {
            WidgetCenter.shared.reloadTimelines(ofKind: SlotKind.kind(for: slot))
        }
    }
}
