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
        // Spec: the side view is used until a photo is chosen.
        if state.carPhotoFile == nil {
            useBuiltInCarPhoto(BuiltInCarPhoto.defaultID)
        }
    }

    /// Renders a bundled photo (with the chosen paint colour and plate) into the App Group as the My Car photo.
    func useBuiltInCarPhoto(_ id: String) {
        guard let photo = BuiltInCarPhoto.all.first(where: { $0.id == id }),
              let png = CarPhotoRenderer.render(photo, paintHex: state.carPaintHex, plate: state.plateText, font: state.plateFont ?? .classic) else {
            lastError = "Couldn't prepare that photo."
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appending(path: StudioState.carPhotoFileName, directoryHint: .notDirectory)
            try png.write(to: target, options: .atomic)
            var next = state
            next.builtInCarPhoto = id
            next.carPhotoFile = StudioState.carPhotoFileName
            state = next
            setCarPhoto(file: StudioState.carPhotoFileName)
        } catch {
            lastError = "Couldn't use that photo: \(error.localizedDescription)"
        }
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

    /// Your own cut-out photo replaces the built-in one.
    func setCustomCarPhoto() {
        var next = state
        next.builtInCarPhoto = nil
        state = next
        setCarPhoto(file: StudioState.carPhotoFileName)
    }

    func setCarPhoto(file: String?, plate: String? = nil) {
        var next = state
        next.carPhotoFile = file
        if let plate { next.plateText = plate }
        commit(next, reloadSlotsShowing: Set(next.designs.filter { $0.layers.contains { $0.content == .carPhoto || $0.content == .plate("") } }.map(\.id)))
    }

    /// Paint colour of the built-in photos (nil = original blue). Re-renders the photo in use.
    func setPaint(_ hex: UInt32?) {
        var next = state
        next.carPaintHex = hex
        commit(next, reloadSlotsShowing: [])
        rerenderBuiltIn()
    }

    func setPlateFont(_ font: PlateFont) {
        var next = state
        next.plateFont = font
        commit(next, reloadSlotsShowing: Set(next.designs.map(\.id)))
        rerenderBuiltIn()
    }

    private func rerenderBuiltIn() {
        if let id = state.builtInCarPhoto { useBuiltInCarPhoto(id) }
    }

    func setPlate(_ text: String) {
        var next = state
        next.plateText = text
        commit(next, reloadSlotsShowing: Set(next.designs.map(\.id)))
        rerenderBuiltIn()
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

/// Built-in My Car photos (spec §4b): supplied by the owner, cut out, lion badges pixelated.
/// Files: `Resources/MyCar/mycar-<id>.png`.
struct BuiltInCarPhoto: Identifiable {
    let id: String
    let name: String
    /// Corners of the white show plate, measured from the photo; nil when no plate is visible.
    var plateQuad: PlateQuad? = nil

    var resource: String { "mycar-\(id)" }

    static let defaultID = "side"

    static let all: [BuiltInCarPhoto] = [
        BuiltInCarPhoto(id: "side", name: "Side"),
        BuiltInCarPhoto(id: "front-three-quarter", name: "Front ¾", plateQuad: PlateQuad((575, 406), (762, 398), (762, 455), (575, 464))),
        BuiltInCarPhoto(id: "rear-three-quarter", name: "Rear ¾", plateQuad: PlateQuad((87, 174), (186, 172), (184, 200), (82, 203))),
        BuiltInCarPhoto(id: "front", name: "Front", plateQuad: PlateQuad((380, 555), (587, 554), (587, 631), (380, 632))),
        BuiltInCarPhoto(id: "front-detail", name: "Front detail", plateQuad: PlateQuad((828, 377), (892, 339), (890, 413), (830, 455))),
    ]
}
